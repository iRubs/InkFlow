import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:inkflow/features/editor/presentation/editor_screen.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';
import 'package:inkflow/core/storage/atomic_json_store.dart';
import 'package:inkflow/data/database/app_database.dart';
import 'package:inkflow/features/export/presentation/widgets/export_dialog.dart';
import 'package:inkflow/features/pdf/presentation/pdf_annotation_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'PDF nativo: importar, anotar dos páginas, reabrir y exportar completo',
    (tester) async {
      final temp = await Directory.systemTemp.createTemp(
        'inkflow_native_integration_',
      );
      final source = pw.Document();
      source.addPage(pw.Page(build: (_) => pw.Text('Original page ONE')));
      source.addPage(pw.Page(build: (_) => pw.Text('Original page TWO')));
      final file = File('${temp.path}/input.pdf');
      await file.writeAsBytes(await source.save());
      final page = Page(
        id: 'integration-pdf',
        sectionId: 'section',
        title: 'PDF · Prueba de integración',
        pageType: 'pdf',
        templateId: 'blank',
        paperColor: '#FFFFFF',
        orientation: 'portrait',
        paperSize: 'A4',
        isFavorite: false,
        isDeleted: false,
        sortOrder: 0,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final screenshot = GlobalKey();
      Future<void> mount() async {
        await tester.pumpWidget(
          ProviderScope(
            child: RepaintBoundary(
              key: screenshot,
              child: MaterialApp(
                home: PdfAnnotationScreen(
                  page: page,
                  initialPdfFile: file,
                  baseDirectory: temp,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle(const Duration(milliseconds: 200));
      }

      await mount();
      expect(find.text('Página 1 de 2'), findsOneWidget);
      Future<void> draw(int pointer, Offset from, Offset to) async {
        final box = tester.renderObject<RenderBox>(
          find.byKey(const ValueKey('pdf-ink-input')),
        );
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.stylus,
          pointer: pointer,
        );
        await gesture.down(box.localToGlobal(from));
        await gesture.moveTo(box.localToGlobal(to));
        await gesture.up();
        await tester.pumpAndSettle();
        await AtomicJsonStore.flush();
      }

      await draw(10, const Offset(80, 120), const Offset(180, 125));
      await tester.tap(find.byTooltip('Página siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Página 2 de 2'), findsOneWidget);
      await draw(11, const Offset(70, 160), const Offset(210, 160));
      final first = jsonDecode(
        await File('${temp.path}/InkFlowData/strokes/integration-pdf_p1.json')
            .readAsString(),
      ) as Map;
      final second = jsonDecode(
        await File('${temp.path}/InkFlowData/strokes/integration-pdf_p2.json')
            .readAsString(),
      ) as Map;
      expect((first['strokes'] as List).length, 1);
      expect((second['strokes'] as List).length, 1);
      expect(
        (first['strokes'] as List).first['points'][0]['x'],
        closeTo(80, 0.1),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await mount();
      await tester.tap(find.byTooltip('Exportar PDF completo'));
      await tester.pumpAndSettle();
      final dialog = tester.widget<ExportDialog>(find.byType(ExportDialog));
      final exported = await dialog.pdfExporter!('${temp.path}/output.pdf');
      final verified = await PdfDocument.openFile(exported.path);
      expect(verified.pages, hasLength(2));
      await verified.dispose();
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      const outputDir = String.fromEnvironment('INKFLOW_TEST_ARTIFACTS');
      if (outputDir.isNotEmpty) {
        final image =
            await (screenshot.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(outputDir).create(recursive: true);
        await File('$outputDir/pdf-integration.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
        await exported.copy('$outputDir/pdf-integration.pdf');
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await temp.delete(recursive: true);
    },
  );

  testWidgets(
    'Cierre normal guarda una transacción del editor antes del debounce',
    (tester) async {
      final temp = await Directory.systemTemp.createTemp(
        'inkflow_editor_close_',
      );
      final page = Page(
        id: 'editor-close',
        sectionId: 's',
        title: 'Autoguardado',
        pageType: 'text',
        templateId: 'blank',
        paperColor: '#FFFFFF',
        orientation: 'portrait',
        paperSize: 'A4',
        isFavorite: false,
        isDeleted: false,
        sortOrder: 0,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: const [
              AppFlowyEditorLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: EditorScreen(page: page, baseDirectory: temp),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final editor = tester
          .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
          .editorState;
      final transaction = editor.transaction
        ..insertNode([0], paragraphNode(text: 'Texto conservado al cerrar'));
      await editor.apply(transaction);
      await tester.pump();
      expect(
        await WidgetsBinding.instance.handleRequestAppExit(),
        ui.AppExitResponse.exit,
      );
      final json = await AtomicJsonStore.read(
        File('${temp.path}/InkFlowData/editor/editor-close.json'),
      );
      expect(jsonEncode(json), contains('Texto conservado al cerrar'));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await AtomicJsonStore.flush();
      await temp.delete(recursive: true);
    },
  );
}
