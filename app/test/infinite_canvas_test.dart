import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:inkflow/core/storage/atomic_json_store.dart';
import 'package:inkflow/features/canvas/models/canvas_image.dart';
import 'package:inkflow/features/canvas/models/stroke.dart';
import 'package:inkflow/features/canvas/presentation/canvas_screen.dart';
import 'package:inkflow/features/canvas/presentation/widgets/infinite_canvas_viewport.dart';
import 'package:inkflow/features/canvas/services/attachment_manager.dart';
import 'package:inkflow/features/canvas/services/canvas_content_bounds.dart';
import 'package:inkflow/features/export/services/export_service.dart';

import 'audit_canvas_test.dart' show testPage, ink;

class BytesOnlyPicker extends FilePicker {
  Uint8List bytes;
  BytesOnlyPicker(this.bytes);
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => FilePickerResult([
    PlatformFile(name: 'foto.png', size: bytes.length, bytes: bytes),
  ]);
}

Uint8List photo() => Uint8List.fromList(
  img.encodePng(
    img.Image(width: 400, height: 100)..clear(img.ColorRgb8(220, 30, 50)),
  ),
);

void main() {
  testWidgets(
    'Imagen sin ruta: importar, mantener proporción, deshacer y rehacer',
    (tester) async {
      final temp = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('inkflow_images_'),
      ))!;
      FilePicker.platform = BytesOnlyPicker(photo());
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: CanvasScreen(
              page: testPage().copyWith(paperSize: 'Infinite'),
              baseDirectory: temp,
              initialStrokes: const [],
            ),
          ),
        ),
      );
      await tester.pump();
      final camera = tester
          .widget<InfiniteCanvasViewport>(find.byType(InfiniteCanvasViewport))
          .controller;
      camera.value = Matrix4.diagonal3Values(0.1, 0.1, 1)
        ..setEntry(0, 3, -5000)
        ..setEntry(1, 3, 2000);
      await tester.pump();
      await tester.tap(find.byTooltip('Añadir imagen'));
      for (var i = 0; i < 30 && find.byType(Image).evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(find.byType(Image), findsOneWidget);
      final box = tester.getRect(find.byType(Image));
      final placement = tester.widget<Positioned>(
        find
            .ancestor(of: find.byType(Image), matching: find.byType(Positioned))
            .first,
      );
      expect(placement.width! / placement.height!, closeTo(4, 0.01));
      final viewport = tester.getRect(
        find.byKey(const ValueKey('ink-canvas-input')),
      );
      expect((box.center - viewport.center).distance, lessThan(1));
      await tester.tap(find.byTooltip('Deshacer (Ctrl+Z)'));
      await tester.pump();
      expect(find.byType(Image), findsNothing);
      await tester.tap(find.byTooltip('Rehacer (Ctrl+Y)'));
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => temp.delete(recursive: true));
    },
  );

  testWidgets(
    'Lienzo sin límites: coordenadas lejanas, dedos y zoom sin desplazar la tinta',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: CanvasScreen(
              page: testPage().copyWith(paperSize: 'Infinite'),
              baseDirectory: Directory.systemTemp,
              initialStrokes: const [],
            ),
          ),
        ),
      );
      await tester.pump();
      final camera = tester
          .widget<InfiniteCanvasViewport>(find.byType(InfiniteCanvasViewport))
          .controller;
      camera.value = Matrix4.diagonal3Values(2, 2, 1)
        ..setEntry(0, 3, -10000)
        ..setEntry(1, 3, 7000);
      await tester.pump();
      final input = find.byKey(const ValueKey('ink-canvas-input'));
      final origin = tester.getTopLeft(input);
      final pen = await tester.createGesture(kind: PointerDeviceKind.stylus);
      await pen.down(origin + const Offset(200, 180));
      await pen.moveTo(origin + const Offset(220, 190));
      await pen.up();
      await tester.pump();
      final stroke = ink(tester).strokes.single;
      expect(stroke.points.first.x, closeTo(5100, 0.01));
      expect(stroke.points.first.y, closeTo(-3410, 0.01));
      final before = camera.value.clone();
      await tester.dragFrom(
        origin + const Offset(300, 250),
        const Offset(0, -200),
      );
      await tester.pump();
      expect(camera.value.entry(1, 3), lessThan(before.entry(1, 3)));
      expect(ink(tester).strokes.single, same(stroke));
      final scaleBefore = camera.value.getMaxScaleOnAxis();
      final left = await tester.createGesture(pointer: 41);
      final right = await tester.createGesture(pointer: 42);
      await left.down(origin + const Offset(200, 200));
      await right.down(origin + const Offset(400, 200));
      await tester.pump();
      await left.moveTo(origin + const Offset(150, 200));
      await right.moveTo(origin + const Offset(450, 200));
      await tester.pump();
      await left.moveTo(origin + const Offset(130, 200));
      await right.moveTo(origin + const Offset(470, 200));
      await tester.pump();
      await left.up();
      await right.up();
      expect(camera.value.getMaxScaleOnAxis(), greaterThan(scaleBefore));
      expect(ink(tester).strokes.single, same(stroke));

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Importación valida imagen y limita resolución sin deformarla', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final temp = await Directory.systemTemp.createTemp('inkflow_import_');
      try {
        final manager = AttachmentManager();
        final large = Uint8List.fromList(
          img.encodePng(img.Image(width: 4096, height: 1024)),
        );
        final saved = await manager.importImageBytes(
          large,
          baseDirectory: temp,
        );
        expect(saved.width, 2048);
        expect(saved.height, 512);
        expect(await File(saved.path).exists(), isTrue);
        await expectLater(
          manager.importImageBytes(Uint8List.fromList([1, 2, 3])),
          throwsA(anything),
        );
        await expectLater(
          manager.importImageBytes(Uint8List(0)),
          throwsFormatException,
        );
      } finally {
        await temp.delete(recursive: true);
      }
    });
  });

  testWidgets('Exportación incluye tinta e imagen en coordenadas negativas', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final temp = await Directory.systemTemp.createTemp('inkflow_bounds_');
      try {
        final file = await File('${temp.path}/photo.png').writeAsBytes(photo());
        final images = [
          CanvasImage(
            id: 'photo',
            filePath: file.path,
            position: const Offset(-5000, -7000),
            width: 400,
            height: 100,
          ),
        ];
        final strokes = [
          const Stroke(
            id: 'ink',
            tool: DrawingToolType.pen,
            color: Colors.black,
            width: 4,
            points: [
              StrokePoint(x: -5000, y: -6800, timestamp: 0),
              StrokePoint(x: -4600, y: -6800, timestamp: 1),
            ],
          ),
        ];
        final bounds = CanvasContentBounds.compute(
          images: images,
          strokes: strokes,
        );
        expect(bounds.left, lessThan(-5000));
        expect(bounds.bottom, greaterThan(-6800));
        final bytes = await ExportService().renderCanvas(
          strokes: strokes,
          images: images,
          canvasBounds: bounds,
          pixelRatio: 1,
        );
        final codec = await ui.instantiateImageCodec(bytes);
        final image = (await codec.getNextFrame()).image;
        final pixels = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final x = (-4800 - bounds.left).round();
        final y = (-6950 - bounds.top).round();
        final offset = (y * image.width + x) * 4;
        expect(pixels!.getUint8(offset), greaterThan(180));
        expect(pixels.getUint8(offset + 1), lessThan(80));
        final inkOffset =
            (((-6800 - bounds.top).round()) * image.width + x) * 4;
        expect(pixels.getUint8(inkOffset), lessThan(80));
        expect(pixels.getUint8(inkOffset + 1), lessThan(80));
        image.dispose();
        codec.dispose();
        final pdf = await ExportService().exportCanvasToPdf(
          outputPath: '${temp.path}/long.pdf',
          strokes: strokes,
          images: images,
          canvasBounds: Rect.fromLTWH(bounds.left, bounds.top, 820, 2400),
          paginate: true,
        );
        expect(await pdf.length(), greaterThan(1000));
      } finally {
        await temp.delete(recursive: true);
      }
    });
  });

  testWidgets('Reabrir conserva imágenes y posición de la cámara', (
    tester,
  ) async {
    final temp = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('inkflow_reopen_'),
    ))!;
    await tester.runAsync(() async {
      final saved = await AttachmentManager().importImageBytes(
        photo(),
        baseDirectory: temp,
      );
      await AtomicJsonStore.write(
        File('${temp.path}/InkFlowData/strokes/audit-canvas.json'),
        {
          'version': 5,
          'isFixedPage': false,
          'strokes': [],
          'camera': {'x': 5000.0, 'y': 7000.0, 'zoom': 1.0},
          'images': [
            CanvasImage(
              id: 'saved',
              filePath: saved.path,
              position: const Offset(-4800, -6800),
              width: 400,
              height: 100,
            ).toJson(),
          ],
        },
      );
    });
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: CanvasScreen(page: testPage(), baseDirectory: temp),
        ),
      ),
    );
    for (var i = 0; i < 30 && find.byType(Image).evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(find.byType(Image), findsOneWidget);
    final camera = tester
        .widget<InfiniteCanvasViewport>(find.byType(InfiniteCanvasViewport))
        .controller;
    expect(camera.value.entry(0, 3), 5000);
    expect(camera.value.entry(1, 3), 7000);
    expect(find.text('Lienzo infinito'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => temp.delete(recursive: true));
  });
}
