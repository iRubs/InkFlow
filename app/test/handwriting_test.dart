import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/canvas/models/stroke.dart';
import 'package:inkflow/features/canvas/models/text_annotation.dart';
import 'package:inkflow/features/canvas/services/handwriting_recognition_service.dart';

void main() {
  group('Pruebas de Anotaciones de Texto (TextAnnotation)', () {
    test('Serialización y deserialización JSON completa de TextAnnotation', () {
      const annotation = TextAnnotation(
        id: 'ann-123',
        text: 'Apuntes de Matemáticas',
        position: Offset(150.0, 220.0),
        fontSize: 28.0,
        fontFamily: 'Caveat',
        color: Color(0xFF2563EB),
        rotation: 0.15,
        width: 200.0,
        height: 40.0,
      );

      final json = annotation.toJson();
      final restored = TextAnnotation.fromJson(json);

      expect(restored.id, equals('ann-123'));
      expect(restored.text, equals('Apuntes de Matemáticas'));
      expect(restored.position.dx, closeTo(150.0, 0.01));
      expect(restored.position.dy, closeTo(220.0, 0.01));
      expect(restored.fontSize, equals(28.0));
      expect(restored.fontFamily, equals('Caveat'));
      expect(
        restored.color.toARGB32(),
        equals(const Color(0xFF2563EB).toARGB32()),
      );
      expect(restored.rotation, closeTo(0.15, 0.01));
      expect(restored.width, equals(200.0));
      expect(restored.height, equals(40.0));
    });

    test('Operaciones de traslación, escalado y cambio de color', () {
      const annotation = TextAnnotation(
        id: 'ann-1',
        text: 'Nota',
        position: Offset(100.0, 100.0),
        fontSize: 20.0,
      );

      // Traslación
      final moved = annotation.translate(const Offset(30.0, -10.0));
      expect(moved.position.dx, equals(130.0));
      expect(moved.position.dy, equals(90.0));

      // Escalado
      final scaled = annotation.scale(1.5, const Offset(100.0, 100.0));
      expect(scaled.fontSize, equals(30.0));

      // Cambio de color
      final colored = annotation.changeColor(Colors.red);
      expect(colored.color, equals(Colors.red));
    });
  });

  test(
    'Motor local pendiente no simula resultados de reconocimiento',
    () async {
      final service = OfflineHandwritingService();
      expect(service.isSupported, isFalse);
      expect(await service.isModelDownloaded('es'), isFalse);
      expect(await service.downloadModel('en'), isFalse);
      final strokes = [
        Stroke(
          id: 'real',
          tool: DrawingToolType.pen,
          color: Colors.black,
          width: 3,
          points: List.generate(
            20,
            (i) => StrokePoint(x: i * 5, y: i * 3, timestamp: i),
          ),
        ),
      ];
      expect(await service.recognize(strokes), isNull);
    },
  );
}
