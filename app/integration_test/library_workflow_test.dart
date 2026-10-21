import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inkflow/core/storage/atomic_json_store.dart';
import 'package:inkflow/data/database/app_database.dart';
import 'package:inkflow/features/backup/services/backup_service.dart';
import 'package:inkflow/features/canvas/presentation/widgets/advanced_color_picker_dialog.dart';
import 'package:inkflow/features/canvas/services/palette_manager.dart';
import 'package:inkflow/features/home/presentation/home_screen.dart';
import 'package:inkflow/features/library/services/page_deletion_service.dart';
import 'package:inkflow/shared/providers/database_provider.dart';

import '../test/library_test.dart' show seedLibrary;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Organizar páginas, purgar con confirmación y restaurar etiquetas/paletas desde respaldo',
    (tester) async {
      final temp = await Directory.systemTemp.createTemp(
        'inkflow_native_library_',
      );
      final data = Directory('${temp.path}/InkFlowData');
      await data.create();
      final db = AppDatabase(
        NativeDatabase(File('${data.path}/inkflow.sqlite')),
      );
      final screenshot = GlobalKey();
      AppDatabase? restoredDb;
      var closed = false;
      try {
        await seedLibrary(db);
        await db.renamePage('a', 'Álgebra · Primer parcial');
        await db.setPageTags('a', ['Universidad', 'Matemáticas']);
        await db.togglePageFavorite('a');
        final palettes = PaletteManager.detached();
        await palettes.initialize(baseDirectory: temp);
        palettes.saveCustomPalette('Estudio', [
          const Color(0xff2563eb),
          const Color(0xff059669),
          const Color(0xffdc2626),
        ]);
        palettes.addRecentColor(const Color(0xffd97706));
        await palettes.flush();
        await AtomicJsonStore.write(File('${data.path}/strokes/b.json'), {
          'strokes': [],
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              pageDeletionServiceProvider.overrideWithValue(
                PageDeletionService(db, documentsDirectory: temp),
              ),
            ],
            child: RepaintBoundary(
              key: screenshot,
              child: const MaterialApp(home: HomeScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Páginas'));
        await tester.pumpAndSettle();
        expect(find.text('Álgebra · Primer parcial'), findsOneWidget);
        await tester.tap(find.text('Favoritos').first);
        await tester.pumpAndSettle();
        expect(find.text('Álgebra · Primer parcial'), findsOneWidget);
        expect(find.text('Nota b'), findsNothing);
        const outputDir = String.fromEnvironment('INKFLOW_TEST_ARTIFACTS');
        Future<void> capture(String name) async {
          if (outputDir.isEmpty) return;
          final image =
              await (screenshot.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(outputDir).create(recursive: true);
          await File('$outputDir/$name')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        }

        await capture('library-1.2.png');
        await tester.tap(find.byKey(const ValueKey('page-menu-a')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mover página a papelera'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Papelera'));
        await tester.pumpAndSettle();
        expect(find.text('Álgebra · Primer parcial'), findsOneWidget);
        await tester.tap(find.byTooltip('Restaurar página'));
        await tester.pumpAndSettle();
        await db.softDeletePage('b');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('page-menu-b')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eliminar definitivamente'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(await db.getPageById('b'), isNotNull);
        expect(await File('${data.path}/strokes/b.json').exists(), isTrue);
        await tester.tap(find.byKey(const ValueKey('page-menu-b')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eliminar definitivamente'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eliminar definitivamente'));
        await tester.pumpAndSettle();
        expect(await db.getPageById('b'), isNull);
        expect(await File('${data.path}/strokes/b.json').exists(), isFalse);
        final context = tester.element(find.byType(HomeScreen));
        showDialog<void>(
          context: context,
          builder: (_) => AdvancedColorPickerDialog(
            initialColor: const Color(0xff2563eb),
            onColorSelected: (_) {},
            paletteManager: palettes,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mis paletas'));
        await tester.pumpAndSettle();
        expect(find.text('Estudio'), findsOneWidget);
        await capture('palettes-1.2.png');
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        final backup = await BackupService(database: db).createBackup(
          destinationZipPath: '${temp.path}/library.inkflow',
          customDataDir: data,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await db.close();
        closed = true;
        final restoredDocs = Directory('${temp.path}/restored');
        await restoredDocs.create();
        final target = Directory('${restoredDocs.path}/InkFlowData');
        expect(
          await BackupService().restoreBackup(
            backupZipPath: backup.path,
            customDataDir: target,
          ),
          isTrue,
        );
        restoredDb = AppDatabase(
          NativeDatabase(File('${target.path}/inkflow.sqlite')),
        );
        expect(
          (await restoredDb.watchPageLibrary(favoritesOnly: true).first)
              .single
              .id,
          'a',
        );
        expect(
          (await restoredDb.watchTagsForPage('a').first).map((tag) => tag.name),
          unorderedEquals(['Universidad', 'Matemáticas']),
        );
        expect(await restoredDb.getPageById('b'), isNull);
        final restoredPalettes = PaletteManager.detached();
        await restoredPalettes.initialize(baseDirectory: restoredDocs);
        expect(restoredPalettes.customPalettes['Estudio'], hasLength(3));
        expect(restoredPalettes.recentColors.first, const Color(0xffd97706));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await AtomicJsonStore.flush();
        if (!closed) await db.close();
        await restoredDb?.close();
        await temp.delete(recursive: true);
      }
    },
  );
}
