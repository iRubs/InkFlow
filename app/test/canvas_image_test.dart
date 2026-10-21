import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/canvas/models/canvas_image.dart';

void main() {
  group('Pruebas del Modelo CanvasImage', () {
    test('Serialización y deserialización JSON completa de CanvasImage', () {
      const image = CanvasImage(
        id: 'img-123',
        filePath: 'C:/docs/photo.png',
        position: Offset(40.0, 80.0),
        width: 300.0,
        height: 200.0,
        scale: 1.5,
        rotation: 0.1,
      );

      final json = image.toJson();
      final restored = CanvasImage.fromJson(json);

      expect(restored.id, equals('img-123'));
      expect(restored.filePath, equals('C:/docs/photo.png'));
      expect(restored.position.dx, closeTo(40.0, 0.01));
      expect(restored.position.dy, closeTo(80.0, 0.01));
      expect(restored.width, equals(300.0));
      expect(restored.height, equals(200.0));
      expect(restored.scale, equals(1.5));
      expect(restored.rotation, closeTo(0.1, 0.01));
    });

    test('Límites geométricos (bounds) y detección de punto containsPoint', () {
      const image = CanvasImage(
        id: 'img-1',
        filePath: 'test.jpg',
        position: Offset(100.0, 100.0),
        width: 200.0,
        height: 100.0,
        scale: 1.0,
      );

      expect(image.bounds, equals(const Rect.fromLTWH(100, 100, 200, 100)));
      expect(image.containsPoint(const Offset(150, 150)), isTrue);
      expect(image.containsPoint(const Offset(50, 50)), isFalse);
      expect(image.containsPoint(const Offset(350, 150)), isFalse);
    });

    test('Operaciones de traslación y escalado de CanvasImage', () {
      const image = CanvasImage(
        id: 'img-2',
        filePath: 'test.png',
        position: Offset(50.0, 50.0),
        width: 100.0,
        height: 100.0,
        scale: 1.0,
      );

      final moved = image.translate(const Offset(25.0, -10.0));
      expect(moved.position.dx, equals(75.0));
      expect(moved.position.dy, equals(40.0));

      final scaled = moved.scaleBy(2.0);
      expect(scaled.scale, equals(2.0));
      expect(scaled.bounds.width, equals(200.0));
      expect(scaled.bounds.height, equals(200.0));
    });
  });
}
