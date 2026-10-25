import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/canvas/models/stroke.dart';
import 'package:inkflow/features/canvas/presentation/canvas_screen.dart';
import 'package:inkflow/features/canvas/presentation/widgets/advanced_color_picker_dialog.dart';
import 'package:inkflow/features/canvas/presentation/widgets/infinite_canvas_viewport.dart';
import 'package:inkflow/features/canvas/services/palette_manager.dart';

import 'audit_canvas_test.dart' show testPage, ink;

Future<void> mount(
  WidgetTester tester,
  Size size, {
  double textScale = 1,
}) async {
  await tester.runAsync(() async {
    PaletteManager().reset();
    await PaletteManager().initialize(baseDirectory: Directory.systemTemp);
  });
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: RepaintBoundary(
          key: const ValueKey('screen-capture'),
          child: CanvasScreen(
            page: testPage(),
            baseDirectory: Directory.systemTemp,
            initialStrokes: const [],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<Stroke> draw(WidgetTester tester, Offset start, Offset end) async {
  final origin = tester.getTopLeft(
    find.byKey(const ValueKey('ink-canvas-input')),
  );
  final pen = await tester.createGesture(kind: PointerDeviceKind.stylus);
  await pen.down(origin + start);
  await pen.moveTo(origin + end);
  await pen.up();
  await tester.pump();
  return ink(tester).strokes.last;
}

void main() {
  testWidgets(
    'Duplicar cerca del borde conserva toda la tinta dentro del papel',
    (tester) async {
      await mount(tester, const Size(800, 1200));
      await draw(tester, const Offset(750, 250), const Offset(780, 260));
      await tester.tap(find.text('Lazo'));
      await tester.pump();
      final origin = tester.getTopLeft(
        find.byKey(const ValueKey('ink-canvas-input')),
      );
      final pen = await tester.createGesture(kind: PointerDeviceKind.stylus);
      await pen.down(origin + const Offset(720, 200));
      for (final point in const [
        Offset(795, 200),
        Offset(795, 300),
        Offset(720, 300),
        Offset(720, 200),
      ]) {
        await pen.moveTo(origin + point);
      }
      await pen.up();
      await tester.pump();
      await tester.tap(find.byTooltip('Duplicar Selección'));
      await tester.pump();
      expect(ink(tester).strokes, hasLength(2));
      for (final point in ink(tester).strokes.last.points) {
        expect(point.x, inInclusiveRange(0, 820));
        expect(point.y, greaterThanOrEqualTo(0));
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Hoja de ancho 820: encaje, límites laterales y superior, escritura larga',
    (tester) async {
      await mount(tester, const Size(800, 1200));
      final viewport = find.byKey(const ValueKey('ink-canvas-input'));
      final camera = tester
          .widget<InfiniteCanvasViewport>(find.byType(InfiniteCanvasViewport))
          .controller;
      expect(camera.toScene(const Offset(12, 12)).dx, closeTo(0, .01));
      final scale = camera.value.entry(0, 0);
      expect(scale * 820, closeTo(tester.getSize(viewport).width - 24, .01));
      await tester.dragFrom(tester.getCenter(viewport), const Offset(250, 250));
      await tester.pump();
      expect(camera.value.entry(0, 3), closeTo(12, .01));
      expect(camera.value.entry(1, 3), lessThanOrEqualTo(12));
      await tester.dragFrom(
        tester.getCenter(viewport),
        const Offset(180, -600),
      );
      await tester.pump();
      expect(camera.value.entry(0, 3), closeTo(12, .01));
      expect(camera.value.entry(1, 3), lessThan(-400));
      final stroke = await draw(
        tester,
        const Offset(200, 250),
        const Offset(230, 260),
      );
      expect(stroke.points.first.y, greaterThan(700));
      await tester.tap(find.byTooltip('Volver al inicio'));
      await tester.pump();
      expect(camera.value.entry(1, 3), closeTo(12, .01));
      final edge = await draw(
        tester,
        const Offset(20, 150),
        const Offset(0, 170),
      );
      expect(edge.points.last.x, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Tablet: elegir lápiz, grosor y color y escribir con esos ajustes',
    (tester) async {
      await mount(tester, const Size(800, 1200));
      await tester.tap(find.byKey(const ValueKey('choose-pen')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resaltador'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('choose-ink-width')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Slider));
      await tester.pump();
      await tester.tapAt(const Offset(10, 200));
      await tester.pumpAndSettle();
      final before = ink(tester).strokes.length;
      await tester.tap(find.byKey(const ValueKey('choose-ink-color')));
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(AdvancedColorPickerDialog), findsOneWidget);
      await tester.ensureVisible(
        find.widgetWithText(TextField, '#RRGGBB / #AARRGGBB'),
      );
      await tester.enterText(
        find.widgetWithText(TextField, '#RRGGBB / #AARRGGBB'),
        '#123456',
      );
      await tester.tap(find.byTooltip('Aplicar código HEX'));
      await tester.pump();
      await tester.tap(find.text('Aplicar Color'));
      for (var i = 0; i < 15; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(AdvancedColorPickerDialog), findsNothing);
      final stroke = await draw(
        tester,
        const Offset(200, 200),
        const Offset(230, 220),
      );
      expect(ink(tester).strokes.length, before + 1);
      expect(stroke.tool, DrawingToolType.highlighter);
      expect(stroke.width, greaterThan(5));
      expect(stroke.color, const Color(0xff123456));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Rotación conserva el encaje y los controles, texto grande sin desbordar',
    (tester) async {
      await mount(tester, const Size(390, 844), textScale: 1.5);
      for (final label in ['Lápiz', 'Color', 'Grosor']) {
        expect(find.text(label).hitTestable(), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(1200, 800);
      await tester.pumpAndSettle();
      final camera = tester
          .widget<InfiniteCanvasViewport>(find.byType(InfiniteCanvasViewport))
          .controller;
      expect(camera.value.entry(0, 0) * 820, closeTo(1176, .01));
      expect(find.text('Color').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Vista real de la hoja y barra de tablet', (tester) async {
    // Load a real bundled font to make the rendered review readable.
    final font = FontLoader('ReviewFont')
      ..addFont(rootBundle.load('assets/fonts/FiraCode-Regular.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(
            fontFamily: 'ReviewFont',
            useMaterial3: true,
            colorSchemeSeed: Colors.blue,
          ),
          home: RepaintBoundary(
            key: const ValueKey('screen-capture'),
            child: CanvasScreen(
              page: testPage().copyWith(title: 'Mis apuntes'),
              baseDirectory: Directory.systemTemp,
              initialStrokes: const [],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await draw(tester, const Offset(130, 190), const Offset(340, 220));
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('screen-capture')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('../logs/vertical-canvas-1.3.png')
          .writeAsBytes(png!.buffer.asUint8List());
      image.dispose();
    });
    expect(tester.takeException(), isNull);
  });
}
