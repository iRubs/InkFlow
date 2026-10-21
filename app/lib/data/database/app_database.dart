import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:uuid/uuid.dart';

import 'tables/tables.dart';

part 'app_database.g.dart';

/// Base de datos SQLite local para InkFlow.
/// 100% offline, persistente en el sistema de archivos del usuario.
@DriftDatabase(tables: [Notebooks, Sections, Pages, Tags, PageTags])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (_) async => customStatement('PRAGMA foreign_keys = ON'),
  );

  /// Copia coherente de SQLite, incluyendo transacciones en WAL.
  Future<void> exportSnapshot(String path) =>
      customStatement('VACUUM INTO ?', [path]);

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'inkflow',
      native: DriftNativeOptions(
        databasePath: () async {
          final docs = await getApplicationDocumentsDirectory();
          final directory = Directory(p.join(docs.path, 'InkFlowData'));
          await directory.create(recursive: true);
          final target = File(p.join(directory.path, 'inkflow.sqlite'));
          final legacy = File(p.join(docs.path, 'inkflow.sqlite'));
          if (!await target.exists() && await legacy.exists()) {
            final source = sqlite.sqlite3.open(legacy.path);
            try {
              source.execute('VACUUM INTO ?', [target.path]);
            } finally {
              source.dispose();
            }
          }
          return target.path;
        },
      ),
    );
  }

  // ==========================================
  // OPERACIONES DE CUADERNOS (NOTEBOOKS)
  // ==========================================

  /// Flujo reactivo de todos los cuadernos activos (no eliminados)
  Stream<List<Notebook>> watchActiveNotebooks() {
    return (select(notebooks)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.updatedAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .watch();
  }

  /// Flujo reactivo de cuadernos favoritos
  Stream<List<Notebook>> watchFavoriteNotebooks() {
    return (select(notebooks)
          ..where(
            (tbl) => tbl.isDeleted.equals(false) & tbl.isFavorite.equals(true),
          )
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.updatedAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .watch();
  }

  /// Flujo reactivo de cuadernos en papelera
  Stream<List<Notebook>> watchDeletedNotebooks() {
    return (select(notebooks)
          ..where((tbl) => tbl.isDeleted.equals(true))
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.deletedAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .watch();
  }

  /// Obtener un cuaderno por su ID
  Future<Notebook?> getNotebookById(String id) {
    return (select(
      notebooks,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  /// Crear un nuevo cuaderno
  Future<int> insertNotebook(NotebooksCompanion entry) {
    return into(notebooks).insert(entry);
  }

  /// Actualizar datos de un cuaderno
  Future<bool> updateNotebookData(NotebooksCompanion entry) {
    return update(notebooks).replace(entry);
  }

  /// Alternar estado de favorito de un cuaderno
  Future<void> toggleNotebookFavorite(String id, bool currentStatus) async {
    await (update(notebooks)..where((tbl) => tbl.id.equals(id))).write(
      NotebooksCompanion(
        isFavorite: Value(!currentStatus),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Enviar cuaderno a la papelera (Soft delete)
  Future<void> softDeleteNotebook(String id) async {
    final now = DateTime.now();
    await (update(notebooks)..where((tbl) => tbl.id.equals(id))).write(
      NotebooksCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// Restaurar cuaderno de la papelera
  Future<void> restoreNotebook(String id) async {
    await (update(notebooks)..where((tbl) => tbl.id.equals(id))).write(
      NotebooksCompanion(
        isDeleted: const Value(false),
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Eliminar permanentemente cuaderno
  Future<int> permanentDeleteNotebook(String id) {
    return (delete(notebooks)..where((tbl) => tbl.id.equals(id))).go();
  }

  // ==========================================
  // OPERACIONES DE SECCIONES (SECTIONS)
  // ==========================================

  Stream<List<Section>> watchSectionsForNotebook(String notebookId) {
    return (select(sections)
          ..where((tbl) => tbl.notebookId.equals(notebookId))
          ..orderBy([
            (tbl) =>
                OrderingTerm(expression: tbl.sortOrder, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  Future<int> insertSection(SectionsCompanion entry) {
    return into(sections).insert(entry);
  }

  Future<int> deleteSection(String id) {
    return (delete(sections)..where((tbl) => tbl.id.equals(id))).go();
  }

  // ==========================================
  // OPERACIONES DE PÁGINAS (PAGES)
  // ==========================================

  Stream<List<Page>> watchActivePagesForSection(String sectionId) {
    return (select(pages)
          ..where(
            (tbl) =>
                tbl.sectionId.equals(sectionId) & tbl.isDeleted.equals(false),
          )
          ..orderBy([
            (tbl) =>
                OrderingTerm(expression: tbl.sortOrder, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  Future<Page?> getPageById(String id) {
    return (select(pages)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertPage(PagesCompanion entry) {
    return into(pages).insert(entry);
  }

  Future<bool> updatePageData(PagesCompanion entry) {
    return update(pages).replace(entry);
  }

  Future<void> softDeletePage(String id) async {
    final now = DateTime.now();
    await (update(pages)..where((tbl) => tbl.id.equals(id))).write(
      PagesCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// Excludes pages whose parent notebook is in the trash in every active view.
  Stream<List<Page>> watchPageLibrary({
    String query = '',
    String? notebookId,
    String? sectionId,
    String? tagId,
    bool favoritesOnly = false,
    bool deletedOnly = false,
    PageSort sort = PageSort.recent,
  }) {
    final conditions = <String>[
      'n.is_deleted = 0',
      'p.is_deleted = ${deletedOnly ? 1 : 0}',
    ];
    final variables = <Variable>[];
    void filter(String column, String? value) {
      if (value == null) return;
      conditions.add('$column = ?');
      variables.add(Variable<String>(value));
    }

    filter('n.id', notebookId);
    filter('p.section_id', sectionId);
    if (tagId != null) {
      conditions.add(
        'p.id IN (SELECT page_id FROM page_tags WHERE tag_id = ?)',
      );
      variables.add(Variable<String>(tagId));
    }
    if (favoritesOnly) conditions.add('p.is_favorite = 1');
    final order = switch (sort) {
      PageSort.title => 'p.title COLLATE NOCASE ASC',
      PageSort.oldest => 'p.created_at ASC',
      PageSort.manual => 'p.sort_order ASC',
      PageSort.recent =>
        deletedOnly ? 'p.deleted_at DESC' : 'p.updated_at DESC',
    };
    final term = query.trim().toLowerCase();
    return customSelect(
      'SELECT p.*, t.name AS matched_tag FROM pages p '
      'JOIN sections s ON s.id = p.section_id '
      'JOIN notebooks n ON n.id = s.notebook_id '
      'LEFT JOIN page_tags pt ON pt.page_id = p.id '
      'LEFT JOIN tags t ON t.id = pt.tag_id '
      'WHERE ${conditions.join(' AND ')} ORDER BY $order, p.id ASC',
      variables: variables,
      readsFrom: {pages, sections, notebooks, pageTags, tags},
    ).watch().map((rows) {
      final result = <String, Page>{};
      for (final row in rows) {
        final page = pages.map(row.data);
        final tag = row.readNullable<String>('matched_tag');
        if (term.isEmpty ||
            page.title.toLowerCase().contains(term) ||
            (tag?.toLowerCase().contains(term) ?? false)) {
          result[page.id] = page;
        }
      }
      return result.values.toList();
    });
  }

  Stream<List<Page>> searchPages(String query) =>
      watchPageLibrary(query: query);

  final Map<String, DateTime> _activityTimes = {};

  /// Update recent-note ordering after a successful content save, at most once
  /// every two seconds per page while handwriting generates frequent writes.
  Future<void> recordPageEdited(String id) async {
    final now = DateTime.now();
    final previous = _activityTimes[id];
    if (previous != null &&
        now.difference(previous) < const Duration(seconds: 2)) {
      return;
    }
    _activityTimes[id] = now;
    try {
      await transaction(() async {
        final page = await getPageById(id);
        if (page == null || page.isDeleted) return;
        await (update(pages)..where((row) => row.id.equals(id))).write(
          PagesCompanion(updatedAt: Value(now)),
        );
        final parent = selectOnly(sections)
          ..addColumns([sections.notebookId])
          ..where(sections.id.equals(page.sectionId));
        await (update(notebooks)..where((row) => row.id.isInQuery(parent)))
            .write(NotebooksCompanion(updatedAt: Value(now)));
      });
    } catch (_) {
      _activityTimes.remove(id);
      rethrow;
    }
  }

  Future<void> renamePage(String id, String title) async {
    final value = title.trim();
    if (value.isEmpty || value.length > 200) {
      throw ArgumentError('El título debe tener entre 1 y 200 caracteres.');
    }
    await (update(
      pages,
    )..where((row) => row.id.equals(id) & row.isDeleted.equals(false))).write(
      PagesCompanion(title: Value(value), updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> togglePageFavorite(String id) async {
    await (update(
      pages,
    )..where((row) => row.id.equals(id) & row.isDeleted.equals(false))).write(
      PagesCompanion.custom(
        isFavorite: pages.isFavorite.not(),
        updatedAt: Variable(DateTime.now()),
      ),
    );
  }

  Future<void> restorePage(String id) async {
    await (update(pages)..where((row) => row.id.equals(id))).write(
      PagesCompanion(
        isDeleted: const Value(false),
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// A permanent delete is allowed only after soft deletion.
  Future<int> permanentDeletePage(String id) => (delete(
    pages,
  )..where((row) => row.id.equals(id) & row.isDeleted.equals(true))).go();

  Stream<List<Tag>> watchTags() => (select(
    tags,
  )..orderBy([(row) => OrderingTerm.asc(row.name.lower())])).watch();

  Stream<List<Tag>> watchTagsForPage(String id) =>
      (select(tags)
            ..where(
              (row) => row.id.isInQuery(
                selectOnly(pageTags)
                  ..addColumns([pageTags.tagId])
                  ..where(pageTags.pageId.equals(id)),
              ),
            )
            ..orderBy([(row) => OrderingTerm.asc(row.name.lower())]))
          .watch();

  /// Validate the complete input before changing any association.
  Future<void> setPageTags(String pageId, Iterable<String> names) async {
    final normalized = <String, String>{};
    for (final raw in names) {
      final name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (name.isEmpty) continue;
      if (name.length > 40 || name.contains(',')) {
        throw ArgumentError(
          'Cada etiqueta debe tener hasta 40 caracteres y no contener comas.',
        );
      }
      normalized.putIfAbsent(name.toLowerCase(), () => name);
    }
    if (normalized.length > 12) {
      throw ArgumentError('Puedes asignar hasta 12 etiquetas por página.');
    }
    await transaction(() async {
      final page = await getPageById(pageId);
      if (page == null || page.isDeleted) {
        throw StateError('La página no está disponible.');
      }
      final ids = <String>[];
      final existing = {
        for (final tag in await select(tags).get()) tag.name.toLowerCase(): tag,
      };
      for (final name in normalized.values) {
        var tag = existing[name.toLowerCase()];
        if (tag == null) {
          final id = const Uuid().v4();
          await into(tags).insert(TagsCompanion.insert(id: id, name: name));
          tag = await (select(
            tags,
          )..where((row) => row.id.equals(id))).getSingle();
        }
        ids.add(tag.id);
      }
      await (delete(pageTags)..where((row) => row.pageId.equals(pageId))).go();
      for (final id in ids) {
        await into(pageTags)
            .insert(PageTagsCompanion.insert(pageId: pageId, tagId: id));
      }
      await (update(pages)..where((row) => row.id.equals(pageId))).write(
        PagesCompanion(updatedAt: Value(DateTime.now())),
      );
    });
  }

  Future<void> renameTag(String id, String name) async {
    final normalized = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty ||
        normalized.length > 40 ||
        normalized.contains(',')) {
      throw ArgumentError('Nombre de etiqueta no válido.');
    }
    await transaction(() async {
      final duplicate = (await select(tags).get()).any(
        (tag) =>
            tag.id != id && tag.name.toLowerCase() == normalized.toLowerCase(),
      );
      if (duplicate) {
        throw ArgumentError('Ya existe una etiqueta con ese nombre.');
      }
      await (update(tags)..where((row) => row.id.equals(id))).write(
        TagsCompanion(name: Value(normalized)),
      );
    });
  }

  Future<int> deleteTag(String id) =>
      (delete(tags)..where((row) => row.id.equals(id))).go();
}

enum PageSort { recent, title, oldest, manual }
