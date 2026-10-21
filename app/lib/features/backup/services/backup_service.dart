import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../../core/storage/atomic_json_store.dart';
import '../../../core/app_version.dart';
import '../../../data/database/app_database.dart';

/// ZIP abierto con instantánea SQLite, hashes SHA-256 y restauración preparada.
class BackupService {
  final AppDatabase? database;
  BackupService({this.database});

  Future<Directory> _directory(Directory? custom) async =>
      custom ??
      Directory(
        p.join((await getApplicationDocumentsDirectory()).path, 'InkFlowData'),
      );

  Future<File> createBackup({
    required String destinationZipPath,
    Directory? customDataDir,
  }) async {
    await AtomicJsonStore.flush();
    final dataDir = await _directory(customDataDir);
    if (customDataDir == null && database == null) {
      throw StateError(
        'Se necesita la base de datos abierta para crear un respaldo completo.',
      );
    }
    final archive = Archive();
    final hashes = <String, String>{};
    final destination = p.normalize(p.absolute(destinationZipPath));
    Future<void> add(String name, File file) async {
      final bytes = await file.readAsBytes();
      hashes[name] = sha256.convert(bytes).toString();
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    final scratch = await Directory.systemTemp.createTemp('inkflow_snapshot_');
    try {
      if (database != null) {
        final snapshot = File(p.join(scratch.path, 'inkflow.sqlite'));
        await database!.exportSnapshot(snapshot.path);
        await add('inkflow.sqlite', snapshot);
      }
      if (await dataDir.exists()) {
        await for (final entity in dataDir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is! File ||
              p.normalize(p.absolute(entity.path)) == destination) {
            continue;
          }
          final name = p
              .relative(entity.path, from: dataDir.path)
              .replaceAll('\\', '/');
          if (name.split('/').first.startsWith('.purge-') ||
              name.endsWith('.pending') ||
              name.endsWith('.previous') ||
              name.endsWith('.inkflow') ||
              name.endsWith('.zip') ||
              name == 'inkflow_manifest.json' ||
              name == 'inkflow.sqlite-wal' ||
              name == 'inkflow.sqlite-shm' ||
              name == 'inkflow.sqlite-journal' ||
              (database != null && name == 'inkflow.sqlite')) {
            continue;
          }
          await add(name, entity);
        }
      }
      final manifest = utf8.encode(
        jsonEncode({
          'app': 'InkFlow',
          'version': inkFlowVersion,
          'backupVersion': 2,
          'schemaVersion': 1,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'filesCount': hashes.length,
          'files': hashes,
          'sourceDataDir': dataDir.absolute.path,
          'databaseIncluded': hashes.containsKey('inkflow.sqlite'),
        }),
      );
      archive.addFile(
        ArchiveFile('inkflow_manifest.json', manifest.length, manifest),
      );
      final target = File(destinationZipPath);
      await target.parent.create(recursive: true);
      final pending = File('$destinationZipPath.pending');
      await pending.writeAsBytes(ZipEncoder().encode(archive), flush: true);
      await pending.rename(target.path);
      return target;
    } finally {
      await scratch.delete(recursive: true);
    }
  }

  /// La conexión SQLite debe estar cerrada y ningún editor abierto al restaurar.
  /// Valida TODO antes de tocar datos; conserva el directorio anterior para recuperación.
  Future<bool> restoreBackup({
    required String backupZipPath,
    Directory? customDataDir,
  }) async {
    Directory? staging;
    Directory? previous;
    Directory? dataDir;
    try {
      final archiveFile = File(backupZipPath);
      if (await archiveFile.length() > 512 * 1024 * 1024) return false;
      final archive = ZipDecoder().decodeBytes(
        await archiveFile.readAsBytes(),
        verify: true,
      );
      if (archive.files
              .where((file) => file.name == 'inkflow_manifest.json')
              .length !=
          1) {
        return false;
      }
      final manifestFile = archive.findFile('inkflow_manifest.json');
      if (manifestFile == null) return false;
      final manifest = jsonDecode(
        utf8.decode(manifestFile.content as List<int>),
      ) as Map<String, dynamic>;
      if (manifest['app'] != 'InkFlow' ||
          manifest['backupVersion'] != 2 ||
          manifest['schemaVersion'] != 1 ||
          manifest['files'] is! Map) {
        return false;
      }
      if (customDataDir == null && manifest['databaseIncluded'] != true) {
        return false;
      }
      final hashes = Map<String, dynamic>.from(manifest['files'] as Map);
      if ((manifest['databaseIncluded'] == true) !=
          hashes.containsKey('inkflow.sqlite')) {
        return false;
      }
      final entries = archive.files
          .where((f) => f.name != 'inkflow_manifest.json')
          .toList();
      if (entries.length != hashes.length ||
          entries.length != manifest['filesCount']) {
        return false;
      }
      final names = <String>{};
      var totalSize = 0;
      for (final entry in entries) {
        final name = entry.name;
        final parts = name.split('/');
        // Rechazar también separadores y unidades de Windows en Android.
        if (!entry.isFile ||
            entry.isSymbolicLink ||
            name.contains('\\') ||
            name.contains(':') ||
            parts.any(
              (v) =>
                  v.isEmpty ||
                  v == '..' ||
                  v == '.' ||
                  v.endsWith('.') ||
                  v.endsWith(' '),
            ) ||
            !names.add(name.toLowerCase())) {
          return false;
        }
        totalSize += entry.size;
        if (totalSize > 1024 * 1024 * 1024 || entries.length > 100000) {
          return false;
        }
        if (hashes[name] !=
            sha256.convert(entry.content as List<int>).toString()) {
          return false;
        }
      }
      dataDir = await _directory(customDataDir);
      await dataDir.parent.create(recursive: true);
      staging = await dataDir.parent.createTemp('.inkflow-restore-');
      final oldRoot = manifest['sourceDataDir'] as String?;
      for (final entry in entries) {
        final output = File(
          p.joinAll([staging.path, ...entry.name.split('/')]),
        );
        await output.parent.create(recursive: true);
        var bytes = entry.content as List<int>;
        // Las referencias absolutas antiguas se vuelven portables entre PC y tablet.
        if (entry.name.endsWith('.json') && oldRoot != null) {
          dynamic rebase(dynamic value) {
            if (value is Map) {
              return value.map((key, child) {
                if ((key == 'filePath' || key == 'localFilePath') &&
                    child is String) {
                  final normalized = child.replaceAll('\\', '/');
                  final root = oldRoot.replaceAll('\\', '/');
                  if (normalized.startsWith('$root/')) {
                    return MapEntry(
                      key,
                      p.joinAll([
                        dataDir!.path,
                        ...normalized.substring(root.length + 1).split('/'),
                      ]),
                    );
                  }
                }
                return MapEntry(key, rebase(child));
              });
            }
            if (value is List) return value.map(rebase).toList();
            return value;
          }

          bytes = utf8.encode(
            jsonEncode(rebase(jsonDecode(utf8.decode(bytes)))),
          );
        }
        await output.writeAsBytes(bytes, flush: true);
      }
      if (manifest['databaseIncluded'] == true) {
        final connection = sqlite.sqlite3.open(
          p.join(staging.path, 'inkflow.sqlite'),
          mode: sqlite.OpenMode.readOnly,
        );
        try {
          if (connection.select('PRAGMA quick_check').single.values.single !=
                  'ok' ||
              connection.select('PRAGMA user_version').single.values.single !=
                  1) {
            throw const FormatException(
              'Base de datos inválida o de una versión incompatible.',
            );
          }
          for (final table in [
            'notebooks',
            'sections',
            'pages',
            'tags',
            'page_tags',
          ]) {
            if (connection.select(
              "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
              [table],
            ).isEmpty) {
              throw const FormatException(
                'La base de datos no contiene las tablas de InkFlow.',
              );
            }
          }
        } finally {
          connection.dispose();
        }
      }
      // Renombrado en el mismo volumen. Si la sustitución falla, volver al original.
      if (await dataDir.exists()) {
        previous = Directory(
          '${dataDir.path}.before-restore-${DateTime.now().microsecondsSinceEpoch}',
        );
        await dataDir.rename(previous.path);
      }
      await staging.rename(dataDir.path);
      staging = null;
      return true;
    } catch (error) {
      debugPrint('Respaldo rechazado o restauración fallida: $error');
      if (previous != null && dataDir != null && !await dataDir.exists()) {
        await previous.rename(dataDir.path);
      }
      return false;
    } finally {
      if (staging != null && await staging.exists()) {
        await staging.delete(recursive: true);
      }
    }
  }
}
