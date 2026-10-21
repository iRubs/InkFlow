import 'dart:io';
import 'dart:ui' as ui;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/canvas/models/canvas_image.dart';
import 'package:inkflow/features/canvas/models/placed_sticker.dart';
import 'package:inkflow/features/export/services/export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('inkflow_export_audit_');
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });
  test(
    'PNG conserva los píxeles de una imagen insertada y un sticker',
    () async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 10, 10),
        Paint()..color = Colors.red,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(10, 10);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final source = File('${temp.path}/red.png');
      await source.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
      final file = await ExportService().exportCanvasToPng(
        outputPath: '${temp.path}/result.png',
        strokes: [],
        canvasSize: const Size(80, 80),
        pixelRatio: 1,
        images: [
          CanvasImage(
            id: 'image',
            filePath: source.path,
            position: const Offset(10, 10),
            width: 20,
            height: 20,
          ),
        ],
        stickers: [
          PlacedSticker(
            id: 'sticker',
            filePath: source.path,
            position: const Offset(40, 40),
            size: const Size(20, 20),
          ),
        ],
      );
      final codec = await ui.instantiateImageCodec(await file.readAsBytes());
      final output = (await codec.getNextFrame()).image;
      final rgba = await output.toByteData(format: ui.ImageByteFormat.rawRgba);
      for (final position in [const Offset(15, 15), const Offset(45, 45)]) {
        final index = (position.dy.toInt() * 80 + position.dx.toInt()) * 4;
        expect(rgba!.getUint8(index), greaterThan(200));
        expect(rgba.getUint8(index + 1), lessThan(100));
      }
      output.dispose();
      codec.dispose();
    },
  );
  test('Markdown conserva tablas reales de AppFlowy y código multilínea', () {
    final table = TableNode.fromList<String>([
      ['A', 'B'],
      ['C', 'D'],
    ]).node;
    final document = Document(
      root: Node(type: 'page', children: [table]),
    );
    final markdown = ExportService().convertEditorJsonToMarkdown(
      document.toJson(),
    );
    expect(markdown, contains('| --- | --- |'));
    final code = ExportService().convertEditorJsonToMarkdown({
      'document': {
        'children': [
          {
            'type': 'code',
            'data': {
              'delta': [
                {'insert': 'a\nb\nc'},
              ],
            },
          },
        ],
      },
    });
    expect(code, contains('a\nb\nc'));
  });
  test('Exportar dimensiones inválidas falla explícitamente', () async {
    await expectLater(
      ExportService().renderCanvas(strokes: [], canvasSize: const Size(0, 100)),
      throwsArgumentError,
    );
  });
}
