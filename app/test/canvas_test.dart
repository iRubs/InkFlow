import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/data/database/app_database.dart';
import 'package:inkflow/features/canvas/models/lasso_selection.dart';
import 'package:inkflow/features/canvas/models/stroke.dart';
import 'package:inkflow/features/canvas/presentation/canvas_screen.dart';
import 'package:inkflow/features/canvas/presentation/widgets/infinite_canvas_viewport.dart';
import 'package:inkflow/features/canvas/services/shape_recognizer.dart';

void main() {
  group('Pruebas del Motor de Autocorrección de Formas (ShapeRecognizer)', () {
    test('Reconocimiento matemático de Línea Recta', () {
      // Puntos a lo largo de una línea recta de (10, 10) a (110, 10)
      final points = <StrokePoint>[];
      for (int i = 0; i <= 20; i++) {
        points.add(
          StrokePoint(
            x: 10.0 + i * 5.0,
            y: 10.0 + (i % 2 == 0 ? 0.3 : -0.3), // Ligero temblor de mano
            pressure: 0.6,
            timestamp: i * 20,
          ),
        );
      }

      final result = ShapeRecognizer.recognize(points);
      expect(result, isNotNull);
      expect(result!.shapeType, equals('line'));
      expect(result.confidence, greaterThan(0.90));
      expect(result.correctedPoints.first.x, closeTo(10.0, 0.1));
      expect(result.correctedPoints.last.x, closeTo(110.0, 0.1));
    });

    test('Reconocimiento matemático de Círculo', () {
      // Puntos formando un círculo de radio 40 centrado en (100, 100)
      final points = <StrokePoint>[];
      const int count = 30;
      for (int i = 0; i <= count; i++) {
        final angle = (i / count) * 2 * pi;
        points.add(
          StrokePoint(
            x: 100.0 + 40.0 * cos(angle),
            y: 100.0 + 40.0 * sin(angle),
            pressure: 0.5,
            timestamp: i * 20,
          ),
        );
      }

      final result = ShapeRecognizer.recognize(points);
      expect(result, isNotNull);
      expect(result!.shapeType, equals('circle'));
      expect(result.confidence, greaterThan(0.80));
    });

    test('Reconocimiento matemático de Rectángulo', () {
      final points = <StrokePoint>[
        // Borde superior
        const StrokePoint(x: 20, y: 20, timestamp: 0),
        const StrokePoint(x: 80, y: 20, timestamp: 10),
        // Borde derecho
        const StrokePoint(x: 80, y: 60, timestamp: 20),
        // Borde inferior
        const StrokePoint(x: 20, y: 60, timestamp: 30),
        // Cierre
        const StrokePoint(x: 20, y: 20, timestamp: 40),
      ];

      final result = ShapeRecognizer.recognize(points);
      expect(result, isNotNull);
      expect(result!.shapeType, equals('rectangle'));
    });
  });

  group('Pruebas del Lazo de Selección (LassoSelection)', () {
    test('Detección Ray-Casting punto dentro de polígono', () {
      final polygon = [
        const Offset(0, 0),
        const Offset(100, 0),
        const Offset(100, 100),
        const Offset(0, 100),
      ];

      expect(
        LassoSelection.isPointInPolygon(const Offset(50, 50), polygon),
        isTrue,
      );
      expect(
        LassoSelection.isPointInPolygon(const Offset(150, 50), polygon),
        isFalse,
      );
      expect(
        LassoSelection.isPointInPolygon(const Offset(-10, 50), polygon),
        isFalse,
      );
    });

    test('Selección, traslación, duplicación y cambio de color de trazos', () {
      const stroke1 = Stroke(
        id: 's1',
        tool: DrawingToolType.pen,
        color: Colors.black,
        width: 3.0,
        points: [
          StrokePoint(x: 30, y: 30, timestamp: 0),
          StrokePoint(x: 40, y: 40, timestamp: 10),
        ],
      );

      const stroke2 = Stroke(
        id: 's2',
        tool: DrawingToolType.pencil,
        color: Colors.blue,
        width: 2.0,
        points: [
          StrokePoint(x: 200, y: 200, timestamp: 0),
          StrokePoint(x: 210, y: 210, timestamp: 10),
        ],
      );

      final lassoPolygon = [
        const Offset(0, 0),
        const Offset(100, 0),
        const Offset(100, 100),
        const Offset(0, 100),
      ];

      // stroke1 está dentro, stroke2 está fuera
      final selection = LassoSelection.fromPolygon(lassoPolygon, [
        stroke1,
        stroke2,
      ]);
      expect(selection.selectedIds.contains('s1'), isTrue);
      expect(selection.selectedIds.contains('s2'), isFalse);

      // Traslación
      final translated = selection.applyTranslation([
        stroke1,
        stroke2,
      ], const Offset(10, 20));
      final movedS1 = translated.firstWhere((s) => s.id == 's1');
      expect(movedS1.points.first.x, equals(40.0));
      expect(movedS1.points.first.y, equals(50.0));

      // Duplicación
      final (duplicatedStrokes, newSelection) = selection.duplicate([
        stroke1,
        stroke2,
      ]);
      expect(duplicatedStrokes.length, equals(3));
      expect(newSelection.selectedIds.length, equals(1));

      // Cambio de color
      final recolored = selection.applyColor([stroke1, stroke2], Colors.red);
      final redS1 = recolored.firstWhere((s) => s.id == 's1');
      expect(redS1.color, equals(Colors.red));
    });
  });

  group('Pruebas de Interfaz de CanvasScreen', () {
    testWidgets('CanvasScreen se monta con herramientas completas y regla', (
      tester,
    ) async {
      final now = DateTime.now();
      final page = Page(
        id: 'test-canvas-page-1',
        sectionId: 'sec-1',
        title: 'Lienzo de Prueba Stylus',
        pageType: 'canvas',
        templateId: 'ruled',
        paperColor: '#FFFFFF',
        orientation: 'portrait',
        paperSize: 'A4',
        isFavorite: false,
        isDeleted: false,
        deletedAt: null,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: CanvasScreen(
              page: page,
              baseDirectory: Directory.systemTemp,
              initialStrokes: const [],
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verificar título de página en AppBar
      expect(find.text('Lienzo de Prueba Stylus'), findsOneWidget);

      // Verificar presencia del icono de Regla Virtual
      expect(find.byIcon(Icons.straighten_rounded), findsOneWidget);

      expect(find.text('Lápiz'), findsOneWidget);
      expect(find.text('Color'), findsOneWidget);
      expect(find.text('Grosor'), findsOneWidget);
      expect(find.byTooltip('Más herramientas'), findsOneWidget);

      // Verificar que el widget interactivo está en el árbol
      expect(find.byType(InfiniteCanvasViewport), findsOneWidget);
    });
  });
}
