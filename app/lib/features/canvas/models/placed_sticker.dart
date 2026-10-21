import 'dart:ui';

/// Representa un sticker colocado e interactivo en el lienzo de InkFlow.
class PlacedSticker {
  final String id;
  final String? assetPath;
  final String? filePath;
  final bool isCustom;
  final Offset position;
  final Size size;
  final double rotation; // En radianes
  final double scale;

  const PlacedSticker({
    required this.id,
    this.assetPath,
    this.filePath,
    this.isCustom = false,
    required this.position,
    this.size = const Size(100, 100),
    this.rotation = 0.0,
    this.scale = 1.0,
  });

  /// Caja envolvente en el lienzo
  Rect get bounds {
    final effectiveWidth = size.width * scale;
    final effectiveHeight = size.height * scale;
    return Rect.fromLTWH(
      position.dx,
      position.dy,
      effectiveWidth,
      effectiveHeight,
    );
  }

  /// Desplaza la posición del sticker
  PlacedSticker translate(Offset delta) {
    return copyWith(position: position + delta);
  }

  /// Escala el tamaño del sticker respecto a su centro
  PlacedSticker scaleBy(double factor) {
    final newScale = (scale * factor).clamp(0.2, 5.0);
    return copyWith(scale: newScale);
  }

  /// Rota el sticker
  PlacedSticker rotateBy(double deltaAngle) {
    return copyWith(rotation: rotation + deltaAngle);
  }

  PlacedSticker copyWith({
    String? id,
    String? assetPath,
    String? filePath,
    bool? isCustom,
    Offset? position,
    Size? size,
    double? rotation,
    double? scale,
  }) {
    return PlacedSticker(
      id: id ?? this.id,
      assetPath: assetPath ?? this.assetPath,
      filePath: filePath ?? this.filePath,
      isCustom: isCustom ?? this.isCustom,
      position: position ?? this.position,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assetPath': assetPath,
      'filePath': filePath,
      'isCustom': isCustom,
      'x': position.dx,
      'y': position.dy,
      'width': size.width,
      'height': size.height,
      'rotation': rotation,
      'scale': scale,
    };
  }

  factory PlacedSticker.fromJson(Map<String, dynamic> json) {
    return PlacedSticker(
      id: json['id'] as String,
      assetPath: json['assetPath'] as String?,
      filePath: json['filePath'] as String?,
      isCustom: json['isCustom'] as bool? ?? false,
      position: Offset(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      ),
      size: Size(
        (json['width'] as num?)?.toDouble() ?? 100.0,
        (json['height'] as num?)?.toDouble() ?? 100.0,
      ),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
    );
  }
}
