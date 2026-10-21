import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/canvas/services/palette_manager.dart';

void main() {
  group('Pruebas del Gestor de Paletas (PaletteManager)', () {
    test('Historial FIFO de colores recientes respeta límite máximo y evita duplicados contiguos', () {
      final manager = PaletteManager();

      // Agregar varios colores
      manager.addRecentColor(const Color(0xFF112233));
      manager.addRecentColor(const Color(0xFF445566));
      manager.addRecentColor(const Color(0xFF778899));

      expect(manager.recentColors.first, equals(const Color(0xFF778899)));

      // Agregar de nuevo el color previo (debe moverse al inicio sin duplicarse)
      manager.addRecentColor(const Color(0xFF112233));
      expect(manager.recentColors.first, equals(const Color(0xFF112233)));
      expect(
        manager.recentColors.where((c) => c == const Color(0xFF112233)).length,
        equals(1),
      );

      // Agregar más colores para exceder el límite de 10
      for (int i = 0; i < 15; i++) {
        manager.addRecentColor(Color(0xFF000000 + i * 100));
      }
      expect(
        manager.recentColors.length,
        equals(PaletteManager.maxRecentColors),
      );
    });

    test(
      'Creación, serialización y recuperación de paletas personalizadas',
      () {
        final manager = PaletteManager();

        const paletteName = 'Paleta Proyecto Arquitectura';
        final colors = [
          const Color(0xFF1E293B),
          const Color(0xFF0284C7),
          const Color(0xFFF59E0B),
        ];

        manager.saveCustomPalette(paletteName, colors);
        expect(manager.customPalettes.containsKey(paletteName), isTrue);
        expect(manager.customPalettes[paletteName]!.length, equals(3));

        // Exportar a JSON
        final jsonStr = manager.exportCustomPalettesJson();
        expect(jsonStr, contains(paletteName));

        // Eliminar y reimportar
        manager.deleteCustomPalette(paletteName);
        expect(manager.customPalettes.containsKey(paletteName), isFalse);

        manager.importCustomPalettesJson(jsonStr);
        expect(manager.customPalettes.containsKey(paletteName), isTrue);
        expect(manager.customPalettes[paletteName]!.length, equals(3));
      },
    );

    test('Paletas temáticas predefinidas contienen colores válidos', () {
      final manager = PaletteManager();
      expect(manager.presetPalettes.containsKey('Clásica'), isTrue);
      expect(manager.presetPalettes.containsKey('Pastel'), isTrue);
      expect(manager.presetPalettes.containsKey('Neón & Resaltador'), isTrue);
      expect(manager.presetPalettes.containsKey('Tierra & Naturaleza'), isTrue);

      for (final palette in manager.presetPalettes.values) {
        expect(palette.isNotEmpty, isTrue);
        for (final color in palette) {
          expect(color.a, greaterThan(0));
        }
      }
    });
  });
}
