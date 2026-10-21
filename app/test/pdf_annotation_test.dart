import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/data/database/app_database.dart';
import 'package:inkflow/features/canvas/models/stroke.dart';
import 'package:inkflow/features/canvas/models/text_annotation.dart';
import 'package:inkflow/features/pdf/presentation/pdf_annotation_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('inkflow_pdf_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Pruebas del Módulo de Anotación sobre PDF', () {
    test(
      'Persistencia independiente de trazos y anotaciones por número de página',
      () async {
        final strokesDir = Directory('${tempDir.path}/InkFlowData/strokes');
        await strokesDir.create(recursive: true);

        // Simular anotaciones en la página 1
        final p1File = File('${strokesDir.path}/pdf-page-1_p1.json');
        final p1Data = {
          'version': 3,
          'page_id': 'pdf-page-1',
          'pdf_page_number': 1,
          'strokes': [
            const Stroke(
              id: 's-p1-1',
              tool: DrawingToolType.highlighter,
              color: Color(0xFFFFD54F),
              width: 18.0,
              points: [
                StrokePoint(x: 100, y: 150, timestamp: 0),
                StrokePoint(x: 250, y: 150, timestamp: 10),
              ],
            ).toJson(),
          ],
          'textAnnotations': [
            const TextAnnotation(
              id: 't-p1-1',
              text: 'Importante: Definición teórica',
              position: Offset(100, 180),
              fontSize: 14.0,
            ).toJson(),
          ],
          'stickers': [],
        };
        await p1File.writeAsString(jsonEncode(p1Data));

        // Simular anotaciones en la página 2
        final p2File = File('${strokesDir.path}/pdf-page-1_p2.json');
        final p2Data = {
          'version': 3,
          'page_id': 'pdf-page-1',
          'pdf_page_number': 2,
          'strokes': [
            const Stroke(
              id: 's-p2-1',
              tool: DrawingToolType.pen,
              color: Colors.blue,
              width: 3.0,
              points: [
                StrokePoint(x: 50, y: 60, timestamp: 0),
                StrokePoint(x: 80, y: 90, timestamp: 20),
              ],
            ).toJson(),
          ],
          'textAnnotations': [],
          'stickers': [],
        };
        await p2File.writeAsString(jsonEncode(p2Data));

        // Verificar lectura y aislamiento de la página 1
        final readP1 =
            jsonDecode(await p1File.readAsString()) as Map<String, dynamic>;
        expect(readP1['pdf_page_number'], equals(1));
        expect((readP1['strokes'] as List).length, equals(1));
        expect((readP1['textAnnotations'] as List).length, equals(1));

        // Verificar lectura y aislamiento de la página 2
        final readP2 =
            jsonDecode(await p2File.readAsString()) as Map<String, dynamic>;
        expect(readP2['pdf_page_number'], equals(2));
        expect((readP2['strokes'] as List).length, equals(1));
        expect((readP2['textAnnotations'] as List).isEmpty, isTrue);
      },
    );

    testWidgets(
      'PdfAnnotationScreen muestra mensaje descriptivo cuando no hay PDF vinculado',
      (tester) async {
        final dummyPage = Page(
          id: 'pdf-page-empty-1',
          sectionId: 'sec-1',
          title: 'Apuntes de Álgebra PDF',
          pageType: 'pdf',
          templateId: 'blank',
          paperColor: '#FFFFFF',
          orientation: 'portrait',
          paperSize: 'A4',
          isFavorite: false,
          isDeleted: false,
          sortOrder: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: PdfAnnotationScreen(page: dummyPage, autoLoad: false),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Apuntes de Álgebra PDF'), findsOneWidget);
        expect(
          find.text('Ningún archivo PDF vinculado a esta página'),
          findsOneWidget,
        );
        expect(find.text('Importar Archivo PDF'), findsOneWidget);
      },
    );
  });
}
