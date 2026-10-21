import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/atomic_json_store.dart';
import '../../../data/database/app_database.dart';

/// Stages local payloads before the SQLite transaction. A restart can restore
/// them if the transaction did not commit, or finish purging after a commit.
class PageDeletionService {
  final AppDatabase database;
  final Directory? documentsDirectory;
  static bool _busy = false;
  PageDeletionService(this.database, {this.documentsDirectory});

  Future<Directory> _root() async => Directory(
    p.join(
      (documentsDirectory ?? await getApplicationDocumentsDirectory()).path,
      'InkFlowData',
    ),
  );

  Future<void> deletePage(String id) async {
    final page = await database.getPageById(id);
    if (page == null || !page.isDeleted) {
      throw StateError('Primero mueve la página a la papelera.');
    }
    await _delete([id], () async {
      if (await database.permanentDeletePage(id) != 1) {
        throw StateError('La página ya no está en la papelera.');
      }
    });
  }

  Future<void> deleteNotebook(String id) async {
    final notebook = await database.getNotebookById(id);
    if (notebook == null || !notebook.isDeleted) {
      throw StateError('Primero mueve el cuaderno a la papelera.');
    }
    final rows = await database
        .customSelect(
          'SELECT p.id FROM pages p JOIN sections s ON s.id = p.section_id WHERE s.notebook_id = ?',
          variables: [Variable<String>(id)],
        )
        .get();
    await _delete(rows.map((row) => row.read<String>('id')).toList(), () async {
      final current = await database.getNotebookById(id);
      if (current == null || !current.isDeleted) {
        throw StateError('El cuaderno ya no está en la papelera.');
      }
      await database.permanentDeleteNotebook(id);
    }, notebookId: id);
  }

  String _safePath(Directory root, String relative) {
    final target = p.normalize(p.join(root.absolute.path, relative));
    if (p.isAbsolute(relative) || !p.isWithin(root.absolute.path, target)) {
      throw const FormatException('Ruta de borrado no válida.');
    }
    return target;
  }

  Future<void> _delete(
    List<String> ids,
    Future<void> Function() remove, {
    String? notebookId,
  }) async {
    if (_busy) throw StateError('Hay otra eliminación en curso.');
    if (ids.any((id) => !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id))) {
      throw const FormatException('Identificador de página no válido.');
    }
    _busy = true;
    Directory? stage;
    var committed = false;
    try {
      await AtomicJsonStore.flush();
      final root = await _root();
      await root.create(recursive: true);
      final payloads = <File>[];
      final candidates = <String>{};
      final references = <String>{};
      var referencesReadable = true;
      void collect(dynamic value, Set<String> paths) {
        if (value is Map) {
          for (final entry in value.entries) {
            if ((entry.key == 'filePath' || entry.key == 'localFilePath') &&
                entry.value is String) {
              paths.add(p.normalize(p.absolute(entry.value as String)));
            }
            collect(entry.value, paths);
          }
        } else if (value is List) {
          for (final item in value) {
            collect(item, paths);
          }
        }
      }

      final names = ids.map(RegExp.escape).join('|');
      final payloadPattern = RegExp(
        '^(?:$names)(?:_p[0-9]+)?\\.json(?:\\.(?:previous|pending))?\$',
      );
      final rootResolved = await root.resolveSymbolicLinks();
      await for (final entity in root.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        final relative = p
            .relative(entity.path, from: root.path)
            .replaceAll('\\', '/');
        if (relative.split('/').first.startsWith('.purge-')) continue;
        final primary =
            ids.isNotEmpty &&
            (((relative.startsWith('strokes/') ||
                        relative.startsWith('editor/')) &&
                    payloadPattern.hasMatch(p.basename(entity.path))) ||
                ids.any((id) => relative == 'attachments/pdfs/$id.pdf'));
        if (!p.isWithin(rootResolved, await entity.resolveSymbolicLinks())) {
          throw const FileSystemException(
            'Un enlace sale de la carpeta de datos.',
          );
        }
        if (primary) payloads.add(entity);
        if (relative.endsWith('.json') ||
            relative.endsWith('.json.previous') ||
            relative.endsWith('.json.pending')) {
          try {
            collect(
              jsonDecode(await entity.readAsString()),
              primary ? candidates : references,
            );
          } catch (_) {
            referencesReadable = false;
          }
        }
      }
      // Never remove shared assets or files outside the managed image directory.
      if (referencesReadable) {
        final imageRoot = p.join(root.absolute.path, 'attachments', 'images');
        for (final candidate in candidates.difference(references)) {
          if (!p.isWithin(imageRoot, candidate)) continue;
          final file = File(candidate);
          if (await file.exists() &&
              p.isWithin(rootResolved, await file.resolveSymbolicLinks())) {
            payloads.add(file);
          }
        }
      }
      stage = Directory(p.join(root.path, '.purge-${const Uuid().v4()}'));
      await stage.create();
      final relativePaths = payloads
          .map((file) => p.relative(file.path, from: root.path))
          .toSet()
          .toList();
      await AtomicJsonStore.write(File(p.join(stage.path, 'manifest.json')), {
        'pageIds': ids,
        'notebookId': notebookId,
        'files': relativePaths,
      });
      for (final relative in relativePaths) {
        final target = File(_safePath(stage, relative));
        await target.parent.create(recursive: true);
        await File(_safePath(root, relative)).rename(target.path);
      }
      await database.transaction(remove);
      committed = true;
      // The resolved target is a newly created child of the data directory.
      if (!p.isWithin(rootResolved, await stage.resolveSymbolicLinks())) {
        throw const FileSystemException('Carpeta de borrado no válida.');
      }
      await stage.delete(recursive: true);
    } catch (_) {
      if (stage != null && !committed) {
        await _recoverStage(await _root(), stage);
      }
      rethrow;
    } finally {
      _busy = false;
    }
  }

  Future<void> recoverPendingDeletions() async {
    final root = await _root();
    if (!await root.exists()) return;
    await for (final entity in root.list(followLinks: false)) {
      if (entity is Directory &&
          p.basename(entity.path).startsWith('.purge-')) {
        await _recoverStage(root, entity);
      }
    }
  }

  Future<void> _recoverStage(Directory root, Directory stage) async {
    final rootResolved = await root.resolveSymbolicLinks();
    if (!p.isWithin(rootResolved, await stage.resolveSymbolicLinks())) {
      throw const FileSystemException('Carpeta de recuperación no válida.');
    }
    final data = await AtomicJsonStore.read(
      File(p.join(stage.path, 'manifest.json')),
    );
    if (data == null) return;
    final ids = List<String>.from(data['pageIds'] as List);
    final notebook = data['notebookId'] as String?;
    final restore = notebook != null
        ? await database.getNotebookById(notebook) != null
        : (await Future.wait(ids.map(database.getPageById)))
              .any((page) => page != null);
    if (restore) {
      for (final relative in List<String>.from(data['files'] as List)) {
        final from = File(_safePath(stage, relative));
        final to = File(_safePath(root, relative));
        if (!await from.exists()) continue;
        if (await to.exists()) {
          throw FileSystemException(
            'Se conserva la recuperación para no sobrescribir datos.',
            to.path,
          );
        }
        await to.parent.create(recursive: true);
        await from.rename(to.path);
      }
    }
    await stage.delete(recursive: true);
  }
}
