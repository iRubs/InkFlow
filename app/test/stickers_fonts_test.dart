import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/canvas/models/placed_sticker.dart';
import 'package:inkflow/features/canvas/services/font_manager.dart';
import 'package:inkflow/features/canvas/services/sticker_manager.dart';

void main() {
  group('Pruebas del Modelo PlacedSticker', () {
    test('Serialización y deserialización JSON de PlacedSticker', () {
      const sticker = PlacedSticker(
        id: 'stk-001',
        assetPath: 'assets/stickers/educacion/excelente.svg',
        isCustom: false,
        position: Offset(120.0, 340.0),
        size: Size(120.0, 120.0),
        rotation: 0.25,
        scale: 1.2,
      );

      final json = sticker.toJson();
      final restored = PlacedSticker.fromJson(json);

      expect(restored.id, equals('stk-001'));
      expect(
        restored.assetPath,
        equals('assets/stickers/educacion/excelente.svg'),
      );
      expect(restored.isCustom, isFalse);
      expect(restored.position.dx, closeTo(120.0, 0.01));
      expect(restored.position.dy, closeTo(340.0, 0.01));
      expect(restored.size.width, closeTo(120.0, 0.01));
      expect(restored.size.height, closeTo(120.0, 0.01));
      expect(restored.rotation, closeTo(0.25, 0.01));
      expect(restored.scale, closeTo(1.2, 0.01));
    });

    test('Cálculo de caja envolvente y transformaciones (traslación, escala, rotación)', () {
      const sticker = PlacedSticker(
        id: 'stk-002',
        position: Offset(50.0, 50.0),
        size: Size(100.0, 100.0),
        scale: 1.0,
      );

      expect(sticker.bounds, equals(const Rect.fromLTWH(50, 50, 100, 100)));

      // Traslación
      final moved = sticker.translate(const Offset(25, -15));
      expect(moved.position, equals(const Offset(75, 35)));

      // Escalado
      final scaled = sticker.scaleBy(1.5);
      expect(scaled.scale, closeTo(1.5, 0.01));
      expect(scaled.bounds.width, closeTo(150.0, 0.01));

      // Rotación
      final rotated = sticker.rotateBy(0.5);
      expect(rotated.rotation, closeTo(0.5, 0.01));
    });
  });

  group('Pruebas del Gestor de Biblioteca de Stickers (StickerManager)', () {
    test(
      'Colección de stickers libres integrados categorizados correctamente',
      () {
        final manager = StickerManager();
        final bundled = manager.bundledStickers;

        expect(bundled.length, equals(14));

        final edu = bundled.where((s) => s.category == 'educacion').toList();
        final org = bundled.where((s) => s.category == 'organizacion').toList();
        final dec = bundled.where((s) => s.category == 'decoracion').toList();

        expect(edu.length, equals(4));
        expect(org.length, equals(5));
        expect(dec.length, equals(5));

        for (final s in bundled) {
          expect(s.assetPath, isNotNull);
          expect(s.assetPath!.endsWith('.svg'), isTrue);
          expect(s.name.isNotEmpty, isTrue);
        }
      },
    );
  });

  group('Pruebas del Gestor de Fuentes (FontManager)', () {
    test('Fuentes libres OFL integradas disponibles por defecto', () {
      final manager = FontManager();
      final fonts = manager.availableFonts;

      expect(fonts.any((f) => f.name == 'Caveat'), isTrue);
      expect(fonts.any((f) => f.name == 'PatrickHand'), isTrue);
      expect(fonts.any((f) => f.name == 'FiraCode'), isTrue);

      final caveat = fonts.firstWhere((f) => f.name == 'Caveat');
      expect(caveat.isBundled, isTrue);
    });
  });
}
