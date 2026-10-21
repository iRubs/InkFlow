import 'dart:math';
import 'dart:ui';

import '../models/stroke.dart';

/// Resultado del reconocimiento y corrección geométrica de una forma dibujada a mano.
class RecognizedShapeResult {
  final String shapeType; // 'line', 'circle', 'rectangle', 'triangle', 'arrow'
  final List<StrokePoint> correctedPoints;
  final double confidence;

  const RecognizedShapeResult({
    required this.shapeType,
    required this.correctedPoints,
    required this.confidence,
  });
}

/// Motor de reconocimiento on-device de formas geométricas para InkFlow.
///
/// Convierte trazos hechos a mano alzada en formas vectoriales perfectas
/// cuando el usuario activa la autocorrección o mantiene presionado el lápiz.
class ShapeRecognizer {
  /// Intenta reconocer una forma geométrica a partir de los puntos del trazo.
  /// Retorna null si el trazo no se ajusta con suficiente confianza a ninguna forma conocida.
  static RecognizedShapeResult? recognize(List<StrokePoint> points) {
    if (points.length < 5) return null;

    final avgPressure =
        points.fold<double>(0.0, (sum, p) => sum + p.pressure) / points.length;
    final timestamp = points.last.timestamp;

    // 1. Detección de Línea Recta
    final lineResult = _detectLine(points, avgPressure, timestamp);
    if (lineResult != null && lineResult.confidence > 0.88) {
      return lineResult;
    }

    // 2. Detección de Círculo
    final circleResult = _detectCircle(points, avgPressure, timestamp);
    if (circleResult != null && circleResult.confidence > 0.82) {
      return circleResult;
    }

    // 3. Detección de Flecha
    final arrowResult = _detectArrow(points, avgPressure, timestamp);
    if (arrowResult != null && arrowResult.confidence > 0.85) {
      return arrowResult;
    }

    // 4. Detección de Rectángulo / Cuadrado
    final rectResult = _detectRectangle(points, avgPressure, timestamp);
    if (rectResult != null && rectResult.confidence > 0.80) {
      return rectResult;
    }

    // 5. Detección de Triángulo
    final triangleResult = _detectTriangle(points, avgPressure, timestamp);
    if (triangleResult != null && triangleResult.confidence > 0.80) {
      return triangleResult;
    }

    return null;
  }

  // ==========================================
  // 1. RECONOCIMIENTO DE LÍNEA RECTA
  // ==========================================
  static RecognizedShapeResult? _detectLine(
    List<StrokePoint> points,
    double pressure,
    int timestamp,
  ) {
    final start = points.first;
    final end = points.last;

    final dx = end.x - start.x;
    final dy = end.y - start.y;
    final directDistance = sqrt(dx * dx + dy * dy);

    if (directDistance < 24.0) return null;

    double totalArcLength = 0.0;
    for (int i = 1; i < points.length; i++) {
      final p1 = points[i - 1];
      final p2 = points[i];
      final segDx = p2.x - p1.x;
      final segDy = p2.y - p1.y;
      totalArcLength += sqrt(segDx * segDx + segDy * segDy);
    }

    if (totalArcLength <= 0.0) return null;

    final linearity = directDistance / totalArcLength;
    if (linearity < 0.90) return null;

    // Calcular desviación perpendicular máxima respecto al segmento start-end
    double maxPerpDist = 0.0;
    for (final p in points) {
      final num =
          ((end.y - start.y) * p.x -
                  (end.x - start.x) * p.y +
                  end.x * start.y -
                  end.y * start.x)
              .abs();
      final perp = num / directDistance;
      if (perp > maxPerpDist) maxPerpDist = perp;
    }

    if (maxPerpDist > directDistance * 0.12) return null;

    // Generar línea recta limpia interpolada
    const int sampleCount = 12;
    final corrected = <StrokePoint>[];
    for (int i = 0; i <= sampleCount; i++) {
      final t = i / sampleCount;
      corrected.add(
        StrokePoint(
          x: start.x + dx * t,
          y: start.y + dy * t,
          pressure: pressure,
          timestamp: timestamp,
        ),
      );
    }

    return RecognizedShapeResult(
      shapeType: 'line',
      correctedPoints: corrected,
      confidence: linearity,
    );
  }

  // ==========================================
  // 2. RECONOCIMIENTO DE CÍRCULO
  // ==========================================
  static RecognizedShapeResult? _detectCircle(
    List<StrokePoint> points,
    double pressure,
    int timestamp,
  ) {
    if (points.length < 12) return null;

    final start = points.first;
    final end = points.last;

    // Longitud total del trazo
    double totalLength = 0.0;
    for (int i = 1; i < points.length; i++) {
      final p1 = points[i - 1];
      final p2 = points[i];
      totalLength += sqrt(pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2));
    }

    final closureDist = sqrt(pow(end.x - start.x, 2) + pow(end.y - start.y, 2));
    // Debe ser una curva que se cierra sobre sí misma
    if (closureDist / totalLength > 0.22) return null;

    // Calcular centroide (centro medio)
    double sumX = 0.0;
    double sumY = 0.0;
    for (final p in points) {
      sumX += p.x;
      sumY += p.y;
    }
    final centerX = sumX / points.length;
    final centerY = sumY / points.length;

    // Calcular radios desde el centro
    final radii = points
        .map((p) => sqrt(pow(p.x - centerX, 2) + pow(p.y - centerY, 2)))
        .toList();
    final avgRadius = radii.reduce((a, b) => a + b) / radii.length;

    if (avgRadius < 12.0) return null;

    // Varianza de los radios
    double variance = 0.0;
    for (final r in radii) {
      variance += pow(r - avgRadius, 2);
    }
    final stdDev = sqrt(variance / radii.length);
    final ratio = stdDev / avgRadius;

    if (ratio > 0.18) return null; // No es lo suficientemente circular

    // Generar círculo geométrico perfecto con 36 puntos
    const int steps = 36;
    final corrected = <StrokePoint>[];
    for (int i = 0; i <= steps; i++) {
      final angle = (i / steps) * 2 * pi;
      corrected.add(
        StrokePoint(
          x: centerX + avgRadius * cos(angle),
          y: centerY + avgRadius * sin(angle),
          pressure: pressure,
          timestamp: timestamp,
        ),
      );
    }

    return RecognizedShapeResult(
      shapeType: 'circle',
      correctedPoints: corrected,
      confidence: 1.0 - ratio,
    );
  }

  // ==========================================
  // 3. RECONOCIMIENTO DE RECTÁNGULO
  // ==========================================
  static RecognizedShapeResult? _detectRectangle(
    List<StrokePoint> points,
    double pressure,
    int timestamp,
  ) {
    final start = points.first;
    final end = points.last;

    double totalLength = 0.0;
    for (int i = 1; i < points.length; i++) {
      totalLength += sqrt(
        pow(points[i].x - points[i - 1].x, 2) +
            pow(points[i].y - points[i - 1].y, 2),
      );
    }

    final closureDist = sqrt(pow(end.x - start.x, 2) + pow(end.y - start.y, 2));
    if (closureDist / totalLength > 0.25) return null;

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

    final width = maxX - minX;
    final height = maxY - minY;

    if (width < 20.0 || height < 20.0) return null;

    // Comprobar que los puntos recorren los 4 bordes del rectángulo
    final perimeter = 2 * (width + height);
    if ((totalLength - perimeter).abs() / perimeter > 0.35) return null;

    // Verificar que los puntos pasen cerca de las 4 esquinas (un círculo nunca toca las esquinas de su caja)
    final corners = [
      Offset(minX, minY),
      Offset(maxX, minY),
      Offset(maxX, maxY),
      Offset(minX, maxY),
    ];
    final cornerThreshold = min(width, height) * 0.20;
    for (final corner in corners) {
      final hasNearCorner = points.any((p) {
        final d = sqrt(pow(p.x - corner.dx, 2) + pow(p.y - corner.dy, 2));
        return d <= cornerThreshold;
      });
      if (!hasNearCorner) return null;
    }

    // Generar rectángulo perfecto con 4 lados cerrados
    final closedCorners = [
      Offset(minX, minY),
      Offset(maxX, minY),
      Offset(maxX, maxY),
      Offset(minX, maxY),
      Offset(minX, minY), // Cierre
    ];

    final corrected = <StrokePoint>[];
    for (int side = 0; side < 4; side++) {
      final p1 = closedCorners[side];
      final p2 = closedCorners[side + 1];
      const int stepsPerSide = 8;
      for (int i = 0; i < stepsPerSide; i++) {
        final t = i / stepsPerSide;
        corrected.add(
          StrokePoint(
            x: p1.dx + (p2.dx - p1.dx) * t,
            y: p1.dy + (p2.dy - p1.dy) * t,
            pressure: pressure,
            timestamp: timestamp,
          ),
        );
      }
    }
    corrected.add(
      StrokePoint(
        x: closedCorners.first.dx,
        y: closedCorners.first.dy,
        pressure: pressure,
        timestamp: timestamp,
      ),
    );

    return RecognizedShapeResult(
      shapeType: 'rectangle',
      correctedPoints: corrected,
      confidence: 0.85,
    );
  }

  // ==========================================
  // 4. RECONOCIMIENTO DE TRIÁNGULO
  // ==========================================
  static RecognizedShapeResult? _detectTriangle(
    List<StrokePoint> points,
    double pressure,
    int timestamp,
  ) {
    final start = points.first;
    final end = points.last;

    double totalLength = 0.0;
    for (int i = 1; i < points.length; i++) {
      totalLength += sqrt(
        pow(points[i].x - points[i - 1].x, 2) +
            pow(points[i].y - points[i - 1].y, 2),
      );
    }

    final closureDist = sqrt(pow(end.x - start.x, 2) + pow(end.y - start.y, 2));
    if (closureDist / totalLength > 0.28) return null;

    // Identificar los 3 vértices más alejados del centro
    double sumX = 0.0;
    double sumY = 0.0;
    for (final p in points) {
      sumX += p.x;
      sumY += p.y;
    }
    final c = Offset(sumX / points.length, sumY / points.length);

    // Encontrar el punto más alejado del centroide (Vértice 1)
    StrokePoint v1 = points.first;
    double maxD1 = 0;
    for (final p in points) {
      final d = sqrt(pow(p.x - c.dx, 2) + pow(p.y - c.dy, 2));
      if (d > maxD1) {
        maxD1 = d;
        v1 = p;
      }
    }

    // Encontrar el punto más alejado de V1 (Vértice 2)
    StrokePoint v2 = points.first;
    double maxD2 = 0;
    for (final p in points) {
      final d = sqrt(pow(p.x - v1.x, 2) + pow(p.y - v1.y, 2));
      if (d > maxD2) {
        maxD2 = d;
        v2 = p;
      }
    }

    // Encontrar el punto que maximice el área del triángulo (Vértice 3)
    StrokePoint v3 = points.first;
    double maxArea = 0;
    for (final p in points) {
      final area =
          (v1.x * (v2.y - p.y) + v2.x * (p.y - v1.y) + p.x * (v1.y - v2.y))
              .abs();
      if (area > maxArea) {
        maxArea = area;
        v3 = p;
      }
    }

    if (maxArea < 200.0) return null;

    final pV1 = Offset(v1.x, v1.y);
    final pV2 = Offset(v2.x, v2.y);
    final pV3 = Offset(v3.x, v3.y);

    double maxDistToSides = 0.0;
    for (final p in points) {
      final d1 = _distToSegment(p, pV1, pV2);
      final d2 = _distToSegment(p, pV2, pV3);
      final d3 = _distToSegment(p, pV3, pV1);
      final minD = min(min(d1, d2), d3);
      if (minD > maxDistToSides) maxDistToSides = minD;
    }
    final side1 = sqrt(pow(pV2.dx - pV1.dx, 2) + pow(pV2.dy - pV1.dy, 2));
    final side2 = sqrt(pow(pV3.dx - pV2.dx, 2) + pow(pV3.dy - pV2.dy, 2));
    final side3 = sqrt(pow(pV1.dx - pV3.dx, 2) + pow(pV1.dy - pV3.dy, 2));
    final minSide = min(min(side1, side2), side3);
    if (minSide < 15.0) return null;
    if (maxDistToSides > minSide * 0.35) return null;

    final vertices = [
      pV1,
      pV2,
      pV3,
      pV1, // Cierre
    ];

    final corrected = <StrokePoint>[];
    for (int side = 0; side < 3; side++) {
      final p1 = vertices[side];
      final p2 = vertices[side + 1];
      const int stepsPerSide = 10;
      for (int i = 0; i < stepsPerSide; i++) {
        final t = i / stepsPerSide;
        corrected.add(
          StrokePoint(
            x: p1.dx + (p2.dx - p1.dx) * t,
            y: p1.dy + (p2.dy - p1.dy) * t,
            pressure: pressure,
            timestamp: timestamp,
          ),
        );
      }
    }
    corrected.add(
      StrokePoint(
        x: vertices.first.dx,
        y: vertices.first.dy,
        pressure: pressure,
        timestamp: timestamp,
      ),
    );

    return RecognizedShapeResult(
      shapeType: 'triangle',
      correctedPoints: corrected,
      confidence: 0.82,
    );
  }

  // ==========================================
  // 5. RECONOCIMIENTO DE FLECHA
  // ==========================================
  static RecognizedShapeResult? _detectArrow(
    List<StrokePoint> points,
    double pressure,
    int timestamp,
  ) {
    if (points.length < 15) return null;

    final start = points.first;
    // La punta de la flecha suele estar cerca del 75-80% del trazo o al final
    // Tomamos el punto más alejado del origen como la punta
    double maxDist = 0;
    int tipIndex = 0;
    for (int i = 0; i < points.length; i++) {
      final d = sqrt(
        pow(points[i].x - start.x, 2) + pow(points[i].y - start.y, 2),
      );
      if (d > maxDist) {
        maxDist = d;
        tipIndex = i;
      }
    }

    if (maxDist < 40.0) return null;
    if (tipIndex < (points.length * 0.5)) return null;

    final tip = points[tipIndex];

    // Verificar si los puntos finales forman alas de flecha hacia atrás
    final remaining = points.sublist(tipIndex);
    if (remaining.length < 4) return null;

    // Calcular vector del eje principal
    final shaftAngle = atan2(tip.y - start.y, tip.x - start.x);
    const arrowHeadLen = 22.0;
    const arrowHeadAngle = 0.55; // ~30 grados

    // Construir flecha perfecta
    final corrected = <StrokePoint>[];

    // Eje principal
    const shaftSteps = 15;
    for (int i = 0; i <= shaftSteps; i++) {
      final t = i / shaftSteps;
      corrected.add(
        StrokePoint(
          x: start.x + (tip.x - start.x) * t,
          y: start.y + (tip.y - start.y) * t,
          pressure: pressure,
          timestamp: timestamp,
        ),
      );
    }

    // Ala izquierda de la cabeza de flecha
    final wing1X = tip.x - arrowHeadLen * cos(shaftAngle - arrowHeadAngle);
    final wing1Y = tip.y - arrowHeadLen * sin(shaftAngle - arrowHeadAngle);
    corrected.add(
      StrokePoint(
        x: wing1X,
        y: wing1Y,
        pressure: pressure,
        timestamp: timestamp,
      ),
    );
    corrected.add(
      StrokePoint(x: tip.x, y: tip.y, pressure: pressure, timestamp: timestamp),
    );

    // Ala derecha de la cabeza de flecha
    final wing2X = tip.x - arrowHeadLen * cos(shaftAngle + arrowHeadAngle);
    final wing2Y = tip.y - arrowHeadLen * sin(shaftAngle + arrowHeadAngle);
    corrected.add(
      StrokePoint(
        x: wing2X,
        y: wing2Y,
        pressure: pressure,
        timestamp: timestamp,
      ),
    );

    return RecognizedShapeResult(
      shapeType: 'arrow',
      correctedPoints: corrected,
      confidence: 0.86,
    );
  }

  static double _distToSegment(StrokePoint p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0) return sqrt(pow(p.x - a.dx, 2) + pow(p.y - a.dy, 2));
    final t = max(
      0.0,
      min(1.0, ((p.x - a.dx) * dx + (p.y - a.dy) * dy) / lenSq),
    );
    final projX = a.dx + t * dx;
    final projY = a.dy + t * dy;
    return sqrt(pow(p.x - projX, 2) + pow(p.y - projY, 2));
  }
}
