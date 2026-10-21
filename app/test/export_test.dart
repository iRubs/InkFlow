import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/canvas/models/stroke.dart';
import 'package:inkflow/features/canvas/models/text_annotation.dart';
import 'package:inkflow/features/export/services/export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExportService exportService;
  late Directory tempDir;

  setUp(() async {
    exportService = ExportService();
    tempDir = await Directory.systemTemp.createTemp('inkflow_export_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Pruebas del Motor de Exportación (ExportService)', () {
    test(
      'Exportación de lienzo con trazos y texto a archivo PDF vectorial',
      () async {
        const stroke1 = Stroke(
          id: 's-pdf-1',
          tool: DrawingToolType.pen,
          color: Colors.blue,
          width: 3.0,
          points: [
            StrokePoint(x: 50, y: 50, timestamp: 0),
            StrokePoint(x: 100, y: 100, timestamp: 10),
            StrokePoint(x: 150, y: 50, timestamp: 20),
          ],
        );

        const annotation1 = TextAnnotation(
          id: 'ann-pdf-1',
          text: 'Nota de Exportación Vectorial',
          position: Offset(50, 150),
          fontSize: 18.0,
          color: Colors.black,
        );

        final pdfPath = '${tempDir.path}/test_export.pdf';

        final resultFile = await exportService.exportCanvasToPdf(
          outputPath: pdfPath,
          strokes: [stroke1],
          textAnnotations: [annotation1],
          canvasSize: const Size(600, 800),
        );

        expect(await resultFile.exists(), isTrue);
        final bytes = await resultFile.readAsBytes();
        expect(bytes.length, greaterThan(100));

        // Verificación de cabecera estándar de formato PDF: %PDF-
        final header = String.fromCharCodes(bytes.take(5));
        expect(header, equals('%PDF-'));
      },
    );

    test(
      'Exportación de lienzo a imagen PNG rasterizada de alta definición',
      () async {
        const stroke = Stroke(
          id: 's-png-1',
          tool: DrawingToolType.fountainPen,
          color: Colors.red,
          width: 4.0,
          points: [
            StrokePoint(x: 20, y: 20, timestamp: 0),
            StrokePoint(x: 80, y: 80, timestamp: 15),
          ],
        );

        final pngPath = '${tempDir.path}/test_export.png';

        final resultFile = await exportService.exportCanvasToPng(
          outputPath: pngPath,
          strokes: [stroke],
          canvasSize: const Size(200, 200),
          pixelRatio: 1.0,
        );

        expect(await resultFile.exists(), isTrue);
        final bytes = await resultFile.readAsBytes();
        expect(bytes.length, greaterThan(50));

        // Verificación de firma mágica de archivo PNG (89 50 4E 47 0D 0A 1A 0A)
        expect(bytes[0], equals(0x89));
        expect(bytes[1], equals(0x50)); // 'P'
        expect(bytes[2], equals(0x4E)); // 'N'
        expect(bytes[3], equals(0x47)); // 'G'
      },
    );

    test(
      'Conversión de árbol de bloques de editor a Markdown estructurado',
      () {
        final editorJson = {
          'document': {
            'children': [
              {
                'type': 'heading',
                'data': {
                  'level': 1,
                  'delta': [
                    {'insert': 'Título Principal'},
                  ],
                },
              },
              {
                'type': 'paragraph',
                'data': {
                  'delta': [
                    {'insert': 'Este es un párrafo de prueba en InkFlow.'},
                  ],
                },
              },
              {
                'type': 'bulleted_list',
                'data': {
                  'delta': [
                    {'insert': 'Punto importante 1'},
                  ],
                },
              },
              {
                'type': 'todo_list',
                'data': {
                  'checked': true,
                  'delta': [
                    {'insert': 'Tarea completada'},
                  ],
                },
              },
              {
                'type': 'todo_list',
                'data': {
                  'checked': false,
                  'delta': [
                    {'insert': 'Tarea pendiente'},
                  ],
                },
              },
              {
                'type': 'quote',
                'data': {
                  'delta': [
                    {'insert': 'Cita célebre'},
                  ],
                },
              },
            ],
          },
        };

        final md = exportService.convertEditorJsonToMarkdown(editorJson);

        expect(md, contains('# Título Principal'));
        expect(md, contains('Este es un párrafo de prueba en InkFlow.'));
        expect(md, contains('- Punto importante 1'));
        expect(md, contains('- [x] Tarea completada'));
        expect(md, contains('- [ ] Tarea pendiente'));
        expect(md, contains('> Cita célebre'));
      },
    );
  });
}
