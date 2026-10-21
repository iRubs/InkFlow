import 'dart:ui';

/// Representa una imagen insertada sobre el lienzo de InkFlow.
///
/// Inmutable y almacenable en formato JSON abierto para persistencia 100% offline.
class CanvasImage {
  final String id;
  final String filePath;
  final Offset position;
  final double width;
  final double height;
  final double scale;
  final double rotation;

  const CanvasImage({
    required this.id,
    required this.filePath,
    required this.position,
    required this.width,
    required this.height,
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  /// Rectángulo delimitador del espacio que ocupa la imagen en el lienzo
  Rect get bounds =>
      Rect.fromLTWH(position.dx, position.dy, width * scale, height * scale);

  /// Verifica si un punto (ej. toque del puntero o stylus) incide sobre la imagen
  bool containsPoint(Offset point) {
    return bounds.contains(point);
  }

  /// Traslada la posición de la imagen
  CanvasImage translate(Offset delta) {
    return copyWith(
      position: Offset(position.dx + delta.dx, position.dy + delta.dy),
    );
  }

  /// Escala la imagen respecto a un factor multiplicativo
  CanvasImage scaleBy(double factor) {
    final newScale = (scale * factor).clamp(0.1, 10.0);
    return copyWith(scale: newScale);
  }

  CanvasImage copyWith({
    String? id,
    String? filePath,
    Offset? position,
    double? width,
    double? height,
    double? scale,
    double? rotation,
  }) {
    return CanvasImage(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      position: position ?? this.position,
      width: width ?? this.width,
      height: height ?? this.height,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': filePath,
      'x': position.dx,
      'y': position.dy,
      'width': width,
      'height': height,
      'scale': scale,
      'rotation': rotation,
    };
  }

  factory CanvasImage.fromJson(Map<String, dynamic> json) {
    return CanvasImage(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      position: Offset(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      ),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
