import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inkflow/core/storage/atomic_json_store.dart';
import 'package:inkflow/features/canvas/presentation/canvas_screen.dart';
import 'package:inkflow/features/canvas/presentation/widgets/infinite_canvas_viewport.dart';
import 'package:inkflow/features/export/services/export_service.dart';
import 'package:inkflow/features/canvas/models/stroke.dart';
import 'package:pdfrx/pdfrx.dart';

import '../test/audit_canvas_test.dart' show testPage;
import '../test/infinite_canvas_test.dart' show BytesOnlyPicker, photo;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Imagen, tinta y cámara persisten fuera de la hoja; PDF de tres páginas',
    (tester) async {
      final temp = await Directory.systemTemp.createTemp(
        'inkflow_native_canvas_',
      );
      final originalPicker = FilePicker.platform;
      final screenshot = GlobalKey();
      final page = testPage().copyWith(
        paperSize: 'Infinite',
        templateId: 'ruled',
      );
      Future<void> mount() async {
        await tester.pumpWidget(
          ProviderScope(
            child: RepaintBoundary(
              key: screenshot,
              child: MaterialApp(
                home: CanvasScreen(page: page, baseDirectory: temp),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      try {
        FilePicker.platform = BytesOnlyPicker(photo());
        await mount();
        final camera = tester
            .widget<InfiniteCanvasViewport>(find.byType(InfiniteCanvasViewport))
            .controller;
        camera.value = Matrix4.diagonal3Values(1.5, 1.5, 1)
          ..setEntry(0, 3, -8000)
          ..setEntry(1, 3, 3000);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Añadir imagen'));
        await tester.pumpAndSettle();
        expect(find.byType(Image), findsOneWidget);
        final initialCenter = tester.getCenter(find.byType(Image));
        await tester.dragFrom(initialCenter, const Offset(90, 60));
        await tester.pumpAndSettle();
        expect(
          (tester.getCenter(find.byType(Image)) -
                  initialCenter -
                  const Offset(90, 60))
              .distance,
          lessThan(1),
        );
        await tester.tap(find.byTooltip('Bolígrafo'));
        await tester.pumpAndSettle();
        final origin = tester.getTopLeft(
          find.byKey(const ValueKey('ink-canvas-input')),
        );
        final pen = await tester.createGesture(
          kind: PointerDeviceKind.stylus,
          pointer: 40,
        );
        await pen.down(origin + const Offset(120, 100));
        await pen.moveTo(origin + const Offset(220, 130));
        await pen.up();
        await tester.pumpAndSettle();
        await AtomicJsonStore.flush();
        final file = File('${temp.path}/InkFlowData/strokes/audit-canvas.json');
        final saved =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        expect(saved['images'], hasLength(1));
        expect(saved['strokes'], hasLength(1));
        expect((saved['images'][0]['x'] as num), greaterThan(5000));
        expect(
          (saved['strokes'][0]['points'][0]['x'] as num),
          greaterThan(5000),
        );
        const outputDir = String.fromEnvironment('INKFLOW_TEST_ARTIFACTS');
        if (outputDir.isNotEmpty) {
          final image =
              await (screenshot.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(outputDir).create(recursive: true);
          await File('$outputDir/canvas-1.1-infinite.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        }
        final pdf = await ExportService().exportCanvasToPdf(
          outputPath: '${temp.path}/three-pages.pdf',
          strokes: [
            const Stroke(
              id: 'long',
              tool: DrawingToolType.pen,
              color: Colors.black,
              width: 4,
              points: [
                StrokePoint(x: -100, y: -100, timestamp: 0),
                StrokePoint(x: -100, y: 2250, timestamp: 1),
              ],
            ),
          ],
          canvasBounds: const Rect.fromLTWH(-200, -200, 820, 2600),
          paginate: true,
        );
        final document = await PdfDocument.openFile(pdf.path);
        expect(document.pages, hasLength(3));
        for (final page in document.pages) {
          final rendered = await page.render(width: 164, height: 232);
          expect(rendered, isNotNull);
          rendered?.dispose();
        }
        await document.dispose();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await mount();
        expect(find.byType(Image), findsOneWidget);
        final restored = tester
            .widget<InfiniteCanvasViewport>(find.byType(InfiniteCanvasViewport))
            .controller;
        expect(restored.value.entry(0, 3), -8000);
        expect(restored.value.entry(1, 3), 3000);
        expect(restored.value.getMaxScaleOnAxis(), 1.5);
        expect(tester.takeException(), isNull);
      } finally {
        FilePicker.platform = originalPicker;
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await AtomicJsonStore.flush();
        await temp.delete(recursive: true);
      }
    },
  );
}
