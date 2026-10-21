import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/core/storage/atomic_json_store.dart';
import 'package:inkflow/data/database/app_database.dart';
import 'package:inkflow/features/backup/services/backup_service.dart';
import 'package:inkflow/features/library/presentation/page_library_view.dart';
import 'package:inkflow/features/home/presentation/widgets/notebook_card.dart';
import 'package:inkflow/features/library/services/page_deletion_service.dart';
import 'package:inkflow/shared/providers/database_provider.dart';

Future<void> seedLibrary(AppDatabase db) async {
  for (final id in ['n1', 'n2']) {
    await db.insertNotebook(NotebooksCompanion.insert(id: id, title: id));
    await db.insertSection(
      SectionsCompanion.insert(
        id: 's$id',
        notebookId: id,
        title: 'Sección $id',
      ),
    );
  }
  for (final id in ['a', 'b', 'c']) {
    await db.insertPage(
      PagesCompanion.insert(
        id: id,
        sectionId: id == 'c' ? 'sn2' : 'sn1',
        title: id == 'a' ? 'ÁLGEBRA I' : 'Nota $id',
      ),
    );
  }
}

Future<void> settle(WidgetTester tester) async {
  for (var attempt = 0; attempt < 4; attempt++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;
  late Directory temp;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    temp = await Directory.systemTemp.createTemp('inkflow_library_');
    await seedLibrary(db);
  });
  tearDown(() async {
    await AtomicJsonStore.flush();
    await db.close();
    await temp.delete(recursive: true);
  });

  test(
    'Etiquetas Unicode, deduplicación, búsqueda literal y borrado en cascada',
    () async {
      await db.setPageTags('a', [' ÁLGEBRA ', 'álgebra', ' Laboratorio   1 ']);
      final tags = await db.watchTagsForPage('a').first;
      expect(tags, hasLength(2));
      expect(tags.map((tag) => tag.name), contains('Laboratorio 1'));
      await db.setPageTags('b', ['álgebra']);
      expect(await db.watchTags().first, hasLength(2));
      expect(
        (await db.searchPages('álgebra').first).map((page) => page.id),
        unorderedEquals(['a', 'b']),
      );
      expect(await db.searchPages('%').first, isEmpty);
      final tag = tags.firstWhere((tag) => tag.name == 'ÁLGEBRA');
      await db.renameTag(tag.id, 'Parcial final');
      expect(
        (await db.searchPages('parcial').first).map((page) => page.id),
        unorderedEquals(['a', 'b']),
      );
      await db.deleteTag(tag.id);
      expect(await db.watchTagsForPage('b').first, isEmpty);
      expect(await db.getPageById('b'), isNotNull);
    },
  );

  test(
    'Etiquetas inválidas no dejan asociaciones ni cambios parciales',
    () async {
      await db.setPageTags('a', ['Original']);
      await expectLater(
        db.setPageTags('a', List.generate(13, (i) => 'Tag $i')),
        throwsArgumentError,
      );
      expect((await db.watchTagsForPage('a').first).single.name, 'Original');
      await db.setPageTags('b', ['Otra']);
      final original = (await db.watchTagsForPage('a').first).single;
      await expectLater(db.renameTag(original.id, 'OTRA'), throwsArgumentError);
      expect((await db.watchTagsForPage('a').first).single.name, 'Original');
    },
  );

  test(
    'Favoritos atómicos, papelera de padres y restauración independiente',
    () async {
      await Future.wait([
        db.togglePageFavorite('a'),
        db.togglePageFavorite('a'),
      ]);
      expect((await db.getPageById('a'))!.isFavorite, isFalse);
      await db.togglePageFavorite('a');
      expect(
        (await db.watchPageLibrary(favoritesOnly: true).first).single.id,
        'a',
      );
      await db.softDeletePage('a');
      expect(await db.watchPageLibrary(favoritesOnly: true).first, isEmpty);
      expect(
        (await db.watchPageLibrary(deletedOnly: true).first).single.id,
        'a',
      );
      await db.softDeleteNotebook('n1');
      expect(await db.watchPageLibrary(deletedOnly: true).first, isEmpty);
      expect((await db.watchPageLibrary().first).single.id, 'c');
      await db.restoreNotebook('n1');
      expect((await db.getPageById('a'))!.isDeleted, isTrue);
      await db.restorePage('a');
      expect(
        (await db.watchPageLibrary(favoritesOnly: true).first).single.id,
        'a',
      );
      expect(await db.permanentDeletePage('a'), 0);
    },
  );

  test(
    'Los filtros reaccionan a cambios de etiquetas sin duplicar páginas',
    () async {
      final iterator = StreamIterator(db.searchPages('Laboratorio'));
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current, isEmpty);
      final update = iterator.moveNext();
      await db.setPageTags('a', ['Laboratorio', 'Laboratorio II']);
      expect(await update, isTrue);
      expect(iterator.current.map((page) => page.id), ['a']);
      await iterator.cancel();
    },
  );

  test(
    'Guardar una nota actualiza la actividad de su página y cuaderno',
    () async {
      await db.customStatement('UPDATE pages SET updated_at = 0');
      await db.customStatement('UPDATE notebooks SET updated_at = 0');
      await db.recordPageEdited('a');
      expect((await db.getPageById('a'))!.updatedAt.year, greaterThan(2020));
      expect(
        (await db.getNotebookById('n1'))!.updatedAt.year,
        greaterThan(2020),
      );
      expect(
        (await db.getNotebookById('n2'))!.updatedAt.millisecondsSinceEpoch,
        0,
      );
      expect((await db.watchPageLibrary().first).first.id, 'a');
    },
  );

  Future<File> write(String relative, String contents) async {
    final file = File('${temp.path}/InkFlowData/$relative');
    await file.parent.create(recursive: true);
    return file.writeAsString(contents);
  }

  test('Borrado definitivo limpia payloads y conserva imágenes compartidas y externas', () async {
    final shared = await write('attachments/images/shared.png', 'shared');
    final own = await write('attachments/images/own.png', 'own');
    final external = File('${temp.path}/external.png');
    await external.writeAsString('external');
    final source = await write(
      'strokes/a.json',
      jsonEncode({
        'images': [
          {'filePath': shared.path},
          {'filePath': own.path},
          {'filePath': external.path},
        ],
      }),
    );
    final other = await write(
      'strokes/b.json',
      jsonEncode({
        'images': [
          {'filePath': shared.path},
        ],
      }),
    );
    final prefix = await write('strokes/abc.json', '{}');
    final annotation = await write('strokes/a_p2.json.previous', '{}');
    final editor = await write('editor/a.json', '{}');
    final pdf = await write('attachments/pdfs/a.pdf', 'pdf');
    final service = PageDeletionService(db, documentsDirectory: temp);
    await expectLater(service.deletePage('a'), throwsStateError);
    expect(await source.exists(), isTrue);
    await db.softDeletePage('a');
    await service.deletePage('a');
    expect(await db.getPageById('a'), isNull);
    for (final file in [source, own, annotation, editor, pdf]) {
      expect(await file.exists(), isFalse);
    }
    for (final file in [shared, other, prefix, external]) {
      expect(await file.exists(), isTrue);
    }
    expect(
      await Directory('${temp.path}/InkFlowData')
          .list()
          .where((file) => file.path.contains('.purge-'))
          .isEmpty,
      isTrue,
    );
  });

  test(
    'Si SQLite rechaza el borrado se recupera el contenido preparado',
    () async {
      final payload = await write('strokes/a.json', '{"strokes":[]}');
      await db.softDeletePage('a');
      await db.customStatement(
        "CREATE TRIGGER prevent_delete BEFORE DELETE ON pages BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
      await expectLater(
        PageDeletionService(db, documentsDirectory: temp).deletePage('a'),
        throwsA(anything),
      );
      expect(await payload.readAsString(), '{"strokes":[]}');
      expect(await db.getPageById('a'), isNotNull);
    },
  );

  test(
    'Recuperación tras interrupción: restaura antes de commit y purga después',
    () async {
      await write('.purge-before/strokes/a.json', '{"strokes":[]}');
      await write(
        '.purge-before/manifest.json',
        jsonEncode({
          'pageIds': ['a'],
          'notebookId': null,
          'files': ['strokes/a.json'],
        }),
      );
      final service = PageDeletionService(db, documentsDirectory: temp);
      await service.recoverPendingDeletions();
      expect(
        await File('${temp.path}/InkFlowData/strokes/a.json').exists(),
        isTrue,
      );
      await db.softDeletePage('a');
      await db.permanentDeletePage('a');
      await write('.purge-after/strokes/a.json', '{"strokes":[]}');
      await write(
        '.purge-after/manifest.json',
        jsonEncode({
          'pageIds': ['a'],
          'notebookId': null,
          'files': ['strokes/a.json'],
        }),
      );
      await service.recoverPendingDeletions();
      expect(
        await Directory('${temp.path}/InkFlowData/.purge-after').exists(),
        isFalse,
      );
    },
  );

  test(
    'Borrado de cuaderno elimina sus páginas y conserva otros cuadernos',
    () async {
      final a = await write('strokes/a.json', '{}');
      final b = await write('editor/b.json', '{}');
      final c = await write('strokes/c.json', '{}');
      await db.softDeleteNotebook('n1');
      await PageDeletionService(
        db,
        documentsDirectory: temp,
      ).deleteNotebook('n1');
      expect(await db.getNotebookById('n1'), isNull);
      expect(await a.exists(), isFalse);
      expect(await b.exists(), isFalse);
      expect(await c.exists(), isTrue);
    },
  );

  test('Respaldo excluye contenido en purga e incluye preferencias', () async {
    await write('.purge-test/strokes/deleted.json', '{}');
    await write('preferences/palettes.json', '{"palettes":{},"recent":[]}');
    final backup = await BackupService(database: db).createBackup(
      destinationZipPath: '${temp.path}/snapshot.inkflow',
      customDataDir: Directory('${temp.path}/InkFlowData'),
    );
    final zip = ZipDecoder().decodeBytes(await backup.readAsBytes());
    expect(zip.files.any((file) => file.name.startsWith('.purge-')), isFalse);
    expect(zip.findFile('preferences/palettes.json'), isNotNull);
  });

  test('Ordenación y filtros de sección y etiqueta se combinan con valores seguros', () async {
    await db.renamePage('a', 'Zeta');
    await db.setPageTags('a', ['Parcial']);
    final tag = (await db.watchTagsForPage('a').first).single;
    expect(
      (await db.watchPageLibrary(sort: PageSort.title).first).map(
        (page) => page.id,
      ),
      ['b', 'c', 'a'],
    );
    expect(
      (await db.watchPageLibrary(sectionId: 'sn1', tagId: tag.id).first)
          .single
          .id,
      'a',
    );
    expect(
      await db.watchPageLibrary(notebookId: 'n2', tagId: tag.id).first,
      isEmpty,
    );
    expect(await db.watchPageLibrary(tagId: "' OR 1=1 --").first, isEmpty);
  });

  test(
    'La recuperación rechaza rutas que salgan de la carpeta preparada',
    () async {
      final outside = File('${temp.path}/outside.txt');
      await outside.writeAsString('conservar');
      await write(
        '.purge-invalid/manifest.json',
        jsonEncode({
          'pageIds': ['a'],
          'notebookId': null,
          'files': ['../outside.txt'],
        }),
      );
      await expectLater(
        PageDeletionService(
          db,
          documentsDirectory: temp,
        ).recoverPendingDeletions(),
        throwsFormatException,
      );
      expect(await outside.readAsString(), 'conservar');
      expect(await db.getPageById('a'), isNotNull);
    },
  );

  testWidgets(
    'La tarjeta de cuaderno funciona sin cargar manualmente fechas en español',
    (tester) async {
      final notebook = (await tester.runAsync(() => db.getNotebookById('n1')))!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            locale: const Locale('en', 'US'),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 220,
                  height: 300,
                  child: NotebookCard(notebook: notebook, onTap: () {}),
                ),
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      expect(find.text('n1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    },
  );

  testWidgets('Biblioteca: buscar, favorito, etiquetas, papelera y restaurar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Future<void> mount({bool favorites = false, bool trash = false}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            pageDeletionServiceProvider.overrideWithValue(
              PageDeletionService(db, documentsDirectory: temp),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PageLibraryView(
                favoritesOnly: favorites,
                deletedOnly: trash,
              ),
            ),
          ),
        ),
      );
      await settle(tester);
    }

    await mount();
    expect(find.text('ÁLGEBRA I'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('page-favorite-a')));
    await settle(tester);
    await mount(favorites: true);
    expect(find.text('ÁLGEBRA I'), findsOneWidget);
    expect(find.text('Nota b'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('page-menu-a')));
    await settle(tester);
    await tester.tap(find.text('Editar etiquetas'));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('page-tags-input')),
      'Examen, ÁLGEBRA',
    );
    await tester.tap(find.text('Guardar etiquetas'));
    await settle(tester);
    expect(find.textContaining('#Examen'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('page-menu-a')));
    await settle(tester);
    await tester.tap(find.text('Mover página a papelera'));
    await settle(tester);
    await mount(trash: true);
    expect(find.text('ÁLGEBRA I'), findsOneWidget);
    await tester.tap(find.byTooltip('Restaurar página'));
    await settle(tester);
    expect(find.text('ÁLGEBRA I'), findsNothing);
    await mount();
    await tester.enterText(
      find.byKey(const ValueKey('library-search')),
      'examen',
    );
    await settle(tester);
    expect(find.text('ÁLGEBRA I'), findsOneWidget);
    expect(find.text('Nota b'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
}
