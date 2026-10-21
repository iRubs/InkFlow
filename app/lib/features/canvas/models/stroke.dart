import 'package:flutter/material.dart';

/// Tipos de herramientas de escritura y dibujo con stylus
enum DrawingToolType {
  pen, // Bolígrafo (grosor estable con ligera variación de presión)
  fountainPen, // Pluma caligráfica (alta respuesta a presión y ángulo)
  pencil, // Lápiz con textura suave y respuesta a inclinación
  brush, // Pincel artístico con trazo suave y dinámico
  highlighter, // Marcador/resaltador semitransparente
  eraser, // Borrador por trazo completo
  pixelEraser, // Borrador por píxel (radio circular preciso)
  lasso, // Lazo de selección interactiva
}

/// Punto de un trazo con información de posición, presión, inclinación y tiempo
class StrokePoint {
  final double x;
  final double y;
  final double pressure; // 0.0 a 1.0
  final double tilt; // Inclinación en radianes (si está disponible)
  final int timestamp;

  const StrokePoint({
    required this.x,
    required this.y,
    this.pressure = 0.5,
    this.tilt = 0.0,
    required this.timestamp,
  });

  Offset get offset => Offset(x, y);

  StrokePoint copyWith({
    double? x,
    double? y,
    double? pressure,
    double? tilt,
    int? timestamp,
  }) {
    return StrokePoint(
      x: x ?? this.x,
      y: y ?? this.y,
      pressure: pressure ?? this.pressure,
      tilt: tilt ?? this.tilt,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'p': pressure,
    if (tilt != 0.0) 'tilt': tilt,
    't': timestamp,
  };

  factory StrokePoint.fromJson(Map<String, dynamic> json) => StrokePoint(
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    pressure: (json['p'] as num?)?.toDouble() ?? 0.5,
    tilt: (json['tilt'] as num?)?.toDouble() ?? 0.0,
    timestamp: json['t'] as int? ?? 0,
  );
}

/// Representa un trazo completo realizado en el lienzo de InkFlow.
class Stroke {
  final String id;
  final DrawingToolType tool;
  final Color color;
  final double width;
  final List<StrokePoint> points;
  final bool isGeometric;
  final String?
  geometricShape; // 'line', 'circle', 'rectangle', 'triangle', 'arrow'

  const Stroke({
    required this.id,
    required this.tool,
    required this.color,
    required this.width,
    required this.points,
    this.isGeometric = false,
    this.geometricShape,
  });

  /// Rectángulo delimitador del trazo para colisiones rápidas y lazo
  Rect get bounds {
    if (points.isEmpty) return Rect.zero;
    double minX = points.first.x;
    double maxX = points.first.x;
    double minY = points.first.y;
    double maxY = points.first.y;

    for (final p in points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    final padding = width / 2;
    return Rect.fromLTRB(
      minX - padding,
      minY - padding,
      maxX + padding,
      maxY + padding,
    );
  }

  /// Desplaza el trazo un delta de coordenadas
  Stroke translate(Offset delta) {
    return copyWith(
      points: points.map((p) {
        return p.copyWith(x: p.x + delta.dx, y: p.y + delta.dy);
      }).toList(),
    );
  }

  /// Escala el trazo respecto a un punto origen
  Stroke scale(double factor, Offset origin) {
    return copyWith(
      width: width * factor,
      points: points.map((p) {
        return p.copyWith(
          x: origin.dx + (p.x - origin.dx) * factor,
          y: origin.dy + (p.y - origin.dy) * factor,
        );
      }).toList(),
    );
  }

  /// Cambia el color del trazo
  Stroke changeColor(Color newColor) {
    return copyWith(color: newColor);
  }

  Stroke copyWith({
    String? id,
    DrawingToolType? tool,
    Color? color,
    double? width,
    List<StrokePoint>? points,
    bool? isGeometric,
    String? geometricShape,
  }) {
    return Stroke(
      id: id ?? this.id,
      tool: tool ?? this.tool,
      color: color ?? this.color,
      width: width ?? this.width,
      points: points ?? this.points,
      isGeometric: isGeometric ?? this.isGeometric,
      geometricShape: geometricShape ?? this.geometricShape,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tool': tool.name,
    'color': color.toARGB32(),
    'width': width,
    'points': points.map((p) => p.toJson()).toList(),
    if (isGeometric) 'isGeometric': isGeometric,
    if (geometricShape != null) 'geometricShape': geometricShape,
  };

  factory Stroke.fromJson(Map<String, dynamic> json) => Stroke(
    id: json['id'] as String,
    tool: DrawingToolType.values.firstWhere(
      (e) => e.name == json['tool'],
      orElse: () => DrawingToolType.pen,
    ),
    color: Color(json['color'] as int),
    width: (json['width'] as num).toDouble(),
    points: (json['points'] as List)
        .map((p) => StrokePoint.fromJson(p as Map<String, dynamic>))
        .toList(),
    isGeometric: json['isGeometric'] as bool? ?? false,
    geometricShape: json['geometricShape'] as String?,
  );
}
