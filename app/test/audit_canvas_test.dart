import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/data/database/app_database.dart';
import 'package:inkflow/features/canvas/models/stroke.dart';
import 'package:inkflow/features/canvas/painters/canvas_painter.dart';
import 'package:inkflow/features/canvas/presentation/canvas_screen.dart';
import 'package:inkflow/features/canvas/presentation/widgets/infinite_canvas_viewport.dart';
import 'package:inkflow/features/canvas/services/stroke_eraser.dart';

Page testPage() => Page(
  id: 'audit-canvas',
  sectionId: 's',
  title: 'Auditoría del lápiz',
  pageType: 'canvas',
  templateId: 'blank',
  paperColor: '#FFFFFF',
  orientation: 'portrait',
  paperSize: 'Infinite',
  isFavorite: false,
  isDeleted: false,
  sortOrder: 0,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

CanvasPainter ink(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((widget) => widget.painter)
    .whereType<CanvasPainter>()
    .last;

void main() {
  test('Borrador corta un segmento largo y no vuelve a unir el hueco', () {
    const stroke = Stroke(
      id: 'line',
      tool: DrawingToolType.pen,
      color: Colors.black,
      width: 3,
      points: [
        StrokePoint(x: 0, y: 50, timestamp: 0),
        StrokePoint(x: 100, y: 50, timestamp: 100),
      ],
    );
    final parts = StrokeEraser.erase(
      stroke,
      const Offset(50, 50),
      10,
      split: true,
    );
    expect(parts, hasLength(2));
    expect(parts.first.points.last.x, closeTo(40, 0.01));
    expect(parts.last.points.first.x, closeTo(60, 0.01));
    expect(StrokeEraser.erase(stroke, const Offset(50, 50), 10), isEmpty);
  });
  testWidgets(
    'Mouse escribe, palma no finaliza el lápiz, deshacer y rehacer restauran',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: CanvasScreen(
              page: testPage(),
              baseDirectory: Directory.systemTemp,
              initialStrokes: const [],
            ),
          ),
        ),
      );
      await tester.pump();
      final input = find.byKey(const ValueKey('ink-canvas-input'));
      final origin = tester.getTopLeft(input);
      final stylus = await tester.createGesture(
        kind: PointerDeviceKind.stylus,
        pointer: 10,
      );
      await stylus.down(origin + const Offset(80, 90));
      await stylus.moveTo(origin + const Offset(100, 100));
      final palm = await tester.createGesture(
        kind: PointerDeviceKind.touch,
        pointer: 11,
      );
      await palm.down(origin + const Offset(150, 150));
      await palm.up();
      await tester.pump();
      expect(ink(tester).activeStroke, isNotNull);
      expect(ink(tester).strokes, isEmpty);
      await stylus.up();
      await tester.pump();
      expect(ink(tester).strokes, hasLength(1));
      await tester.tap(find.byTooltip('Deshacer (Ctrl+Z)'));
      await tester.pump();
      expect(ink(tester).strokes, isEmpty);
      await tester.tap(find.byTooltip('Rehacer (Ctrl+Y)'));
      await tester.pump();
      expect(ink(tester).strokes, hasLength(1));
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        pointer: 12,
      );
      await mouse.down(origin + const Offset(200, 150));
      await mouse.moveTo(origin + const Offset(220, 160));
      await mouse.up();
      await tester.pump();
      expect(ink(tester).strokes, hasLength(2));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(ink(tester).strokes, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Zoom 2x transforma las coordenadas exactamente una vez', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: CanvasScreen(
            page: testPage(),
            baseDirectory: Directory.systemTemp,
            initialStrokes: const [],
          ),
        ),
      ),
    );
    await tester.pump();
    final viewer = tester.widget<InfiniteCanvasViewport>(
      find.byType(InfiniteCanvasViewport),
    );
    viewer.controller.value = Matrix4.diagonal3Values(2, 2, 1);
    await tester.pump();
    final listener = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('ink-canvas-input')),
    );
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.stylus,
      pointer: 15,
    );
    await gesture.down(listener.localToGlobal(const Offset(70, 80)));
    await gesture.moveTo(listener.localToGlobal(const Offset(80, 85)));
    await gesture.up();
    await tester.pump();
    expect(ink(tester).strokes.single.points.first.x, closeTo(35, 0.1));
    expect(ink(tester).strokes.single.points.first.y, closeTo(40, 0.1));
  });
  testWidgets('Barra de herramientas se adapta a pantalla estrecha', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: CanvasScreen(
            page: testPage(),
            baseDirectory: Directory.systemTemp,
            initialStrokes: const [],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
