import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Pruebas de Base de Datos Local Drift (SQLite)', () {
    test('Creación, consulta y actualización de cuadernos', () async {
      final now = DateTime.now();
      const notebookId = 'nb-test-1';

      // 1. Insertar cuaderno
      await db.insertNotebook(
        NotebooksCompanion(
          id: const Value(notebookId),
          title: const Value('Matemáticas Avanzadas'),
          coverColor: const Value('#2563EB'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // 2. Consultar
      final notebook = await db.getNotebookById(notebookId);
      expect(notebook, isNotNull);
      expect(notebook!.title, equals('Matemáticas Avanzadas'));
      expect(notebook.isFavorite, isFalse);
      expect(notebook.isDeleted, isFalse);

      // 3. Alternar favorito
      await db.toggleNotebookFavorite(notebookId, false);
      final updated = await db.getNotebookById(notebookId);
      expect(updated!.isFavorite, isTrue);

      // 4. Soft delete
      await db.softDeleteNotebook(notebookId);
      final inTrash = await db.getNotebookById(notebookId);
      expect(inTrash!.isDeleted, isTrue);
      expect(inTrash.deletedAt, isNotNull);

      // 5. Restaurar
      await db.restoreNotebook(notebookId);
      final restored = await db.getNotebookById(notebookId);
      expect(restored!.isDeleted, isFalse);
    });

    test('Creación de secciones y páginas vinculadas con cascada', () async {
      final now = DateTime.now();
      const notebookId = 'nb-test-2';
      const sectionId = 'sec-test-1';
      const pageId = 'page-test-1';

      await db.insertNotebook(
        NotebooksCompanion(
          id: const Value(notebookId),
          title: const Value('Química Orgánica'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.insertSection(
        SectionsCompanion(
          id: const Value(sectionId),
          notebookId: const Value(notebookId),
          title: const Value('Laboratorio 1'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.insertPage(
        PagesCompanion(
          id: const Value(pageId),
          sectionId: const Value(sectionId),
          title: const Value('Reacciones Redox'),
          templateId: const Value('grid'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final page = await db.getPageById(pageId);
      expect(page, isNotNull);
      expect(page!.title, equals('Reacciones Redox'));
      expect(page.templateId, equals('grid'));
    });
  });
}
