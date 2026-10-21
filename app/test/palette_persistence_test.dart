import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/core/storage/atomic_json_store.dart';
import 'package:inkflow/features/canvas/services/palette_manager.dart';
import 'package:inkflow/features/canvas/presentation/widgets/advanced_color_picker_dialog.dart';

Future<void> settle(WidgetTester tester) async {
  for (var attempt = 0; attempt < 4; attempt++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  await tester.pumpAndSettle();
}

void main() {
  test(
    'Paletas y recientes persisten en disco con copias independientes',
    () async {
      final temp = await Directory.systemTemp.createTemp('inkflow_palette_');
      try {
        final manager = PaletteManager.detached();
        await manager.initialize(baseDirectory: temp);
        manager.saveCustomPalette('Estudio', [
          const Color(0xfff44336),
          const Color(0xff2196f3),
        ]);
        manager.addRecentColor(const Color(0x80123456));
        await manager.flush();
        final restored = PaletteManager.detached();
        await restored.initialize(baseDirectory: temp);
        expect(restored.customPalettes['Estudio'], [
          const Color(0xfff44336),
          const Color(0xff2196f3),
        ]);
        expect(restored.recentColors.first, const Color(0x80123456));
        expect(
          () => restored.customPalettes['Estudio']!.add(Colors.green),
          throwsUnsupportedError,
        );
        restored.replacePalette('Estudio', 'Trabajo', [
          const Color(0xff4caf50),
        ]);
        await restored.flush();
        final next = PaletteManager.detached();
        await next.initialize(baseDirectory: temp);
        expect(next.customPalettes.containsKey('Estudio'), isFalse);
        expect(next.customPalettes['Trabajo'], [const Color(0xff4caf50)]);
        next.deleteCustomPalette('Trabajo');
        await next.flush();
        final empty = PaletteManager.detached();
        await empty.initialize(baseDirectory: temp);
        expect(empty.customPalettes, isEmpty);
      } finally {
        await AtomicJsonStore.flush();
        await temp.delete(recursive: true);
      }
    },
  );

  test('Importación inválida y nombres duplicados no cambian las paletas', () {
    final manager = PaletteManager.detached();
    manager.saveCustomPalette('Original', [const Color(0xfff44336)]);
    manager.saveCustomPalette('Segunda', [Colors.blue]);
    expect(
      () => manager.importCustomPalettesJson(
        '{"Valida":[4294901760],"Rota":["red"]}',
      ),
      throwsFormatException,
    );
    expect(
      manager.customPalettes.keys,
      unorderedEquals(['Original', 'Segunda']),
    );
    expect(
      () => manager.replacePalette('Original', 'SEGUNDA', [
        const Color(0xff4caf50),
      ]),
      throwsArgumentError,
    );
    expect(manager.customPalettes['Original'], [const Color(0xfff44336)]);
    expect(parseInkColor('#ff00aa'), const Color(0xffff00aa));
    expect(parseInkColor('#80123456'), const Color(0x80123456));
    expect(parseInkColor('ZZ0011'), isNull);
  });

  test(
    'Recuperación de JSON truncado y protección de archivos no recuperables',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'inkflow_palette_recovery_',
      );
      try {
        final manager = PaletteManager.detached();
        await manager.initialize(baseDirectory: temp);
        manager.saveCustomPalette('Primera', [const Color(0xfff44336)]);
        await manager.flush();
        manager.saveCustomPalette('Segunda', [Colors.blue]);
        await manager.flush();
        final file = File('${temp.path}/InkFlowData/preferences/palettes.json');
        await file.writeAsString('{');
        final restored = PaletteManager.detached();
        await restored.initialize(baseDirectory: temp);
        expect(restored.customPalettes['Primera'], [const Color(0xfff44336)]);
        expect(restored.customPalettes.containsKey('Segunda'), isFalse);
        await File('${file.path}.previous').writeAsString('{');
        final broken = PaletteManager.detached();
        await expectLater(
          broken.initialize(baseDirectory: temp),
          throwsFormatException,
        );
        broken.saveCustomPalette('No sobrescribir', [const Color(0xff4caf50)]);
        await expectLater(broken.flush(), throwsFormatException);
        expect(await file.readAsString(), '{');
      } finally {
        await AtomicJsonStore.flush();
        await temp.delete(recursive: true);
      }
    },
  );

  testWidgets('Selector HSV se adapta a una ventana horizontal', (
    tester,
  ) async {
    final temp = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('inkflow_palette_landscape_'),
    ))!;
    final manager = PaletteManager.detached();
    await tester.runAsync(() => manager.initialize(baseDirectory: temp));
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdvancedColorPickerDialog(
            initialColor: Colors.black,
            onColorSelected: (_) {},
            paletteManager: manager,
          ),
        ),
      ),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await tester.runAsync(() => temp.delete(recursive: true));
  });

  testWidgets('Crear y editar paleta desde interfaz estrecha y aplicar color', (
    tester,
  ) async {
    final temp = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('inkflow_palette_ui_'),
    ))!;
    final manager = PaletteManager.detached();
    await tester.runAsync(() => manager.initialize(baseDirectory: temp));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Color? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AdvancedColorPickerDialog(
                  initialColor: Colors.black,
                  onColorSelected: (color) => selected = color,
                  paletteManager: manager,
                ),
              ),
              child: const Text('Abrir colores'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir colores'));
    await settle(tester);
    await tester.tap(find.text('Mis paletas'));
    await settle(tester);
    await tester.tap(find.text('Crear paleta'));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('palette-name')),
      'Universidad',
    );
    await tester.enterText(
      find.byKey(const ValueKey('palette-hex')),
      '#123456',
    );
    await tester.tap(find.byTooltip('Añadir color HEX'));
    await settle(tester);
    await tester.tap(find.text('Guardar paleta'));
    for (
      var attempt = 0;
      attempt < 30 && find.byType(PaletteEditorDialog).evaluate().isNotEmpty;
      attempt++
    ) {
      await settle(tester);
    }
    expect(find.byType(PaletteEditorDialog), findsNothing);
    expect(find.text('Universidad'), findsOneWidget);
    await tester.tap(find.byTooltip('Editar paleta Universidad'));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('palette-name')),
      'Facultad',
    );
    await tester.tap(find.text('Guardar paleta'));
    for (
      var attempt = 0;
      attempt < 30 && find.byType(PaletteEditorDialog).evaluate().isNotEmpty;
      attempt++
    ) {
      await settle(tester);
    }
    expect(find.byType(PaletteEditorDialog), findsNothing);
    expect(manager.customPalettes.containsKey('Universidad'), isFalse);
    expect(
      manager.customPalettes['Facultad'],
      contains(const Color(0xff123456)),
    );
    await tester.tap(find.text('Aplicar Color'));
    for (
      var attempt = 0;
      attempt < 30 &&
          find.byType(AdvancedColorPickerDialog).evaluate().isNotEmpty;
      attempt++
    ) {
      await settle(tester);
    }
    expect(selected, Colors.black);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => temp.delete(recursive: true));
  });
}
