import 'package:flutter/material.dart';

/// Representa una anotación de texto en el lienzo de InkFlow.
///
/// Utilizada para:
/// - Texto tipado insertado en el lienzo.
/// - Letra manuscrita convertida a tipografía elegante ("Fuente Bonita").
/// - Texto transcrito mediante reconocimiento on-device.
class TextAnnotation {
  final String id;
  final String text;
  final Offset position;
  final double fontSize;
  final String fontFamily;
  final Color color;
  final double rotation; // En radianes
  final double? width;
  final double? height;

  const TextAnnotation({
    required this.id,
    required this.text,
    required this.position,
    this.fontSize = 24.0,
    this.fontFamily = 'Caveat',
    this.color = Colors.black,
    this.rotation = 0.0,
    this.width,
    this.height,
  });

  /// Desplaza la posición de la anotación de texto.
  TextAnnotation translate(Offset delta) {
    return copyWith(position: position + delta);
  }

  /// Escala la posición y el tamaño de la fuente respecto a un punto de origen.
  TextAnnotation scale(double scaleFactor, Offset origin) {
    final newX = origin.dx + (position.dx - origin.dx) * scaleFactor;
    final newY = origin.dy + (position.dy - origin.dy) * scaleFactor;
    return copyWith(
      position: Offset(newX, newY),
      fontSize: (fontSize * scaleFactor).clamp(8.0, 120.0),
    );
  }

  /// Cambia el color del texto.
  TextAnnotation changeColor(Color newColor) {
    return copyWith(color: newColor);
  }

  TextAnnotation copyWith({
    String? id,
    String? text,
    Offset? position,
    double? fontSize,
    String? fontFamily,
    Color? color,
    double? rotation,
    double? width,
    double? height,
  }) {
    return TextAnnotation(
      id: id ?? this.id,
      text: text ?? this.text,
      position: position ?? this.position,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      color: color ?? this.color,
      rotation: rotation ?? this.rotation,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'x': position.dx,
      'y': position.dy,
      'fontSize': fontSize,
      'fontFamily': fontFamily,
      'color': color.toARGB32(),
      'rotation': rotation,
      'width': width,
      'height': height,
    };
  }

  factory TextAnnotation.fromJson(Map<String, dynamic> json) {
    final colorValue = json['color'] as int? ?? 0xFF000000;
    return TextAnnotation(
      id: json['id'] as String,
      text: json['text'] as String,
      position: Offset(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      ),
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 24.0,
      fontFamily: json['fontFamily'] as String? ?? 'Caveat',
      color: Color(colorValue),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      width: (json['width'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
    );
  }
}
