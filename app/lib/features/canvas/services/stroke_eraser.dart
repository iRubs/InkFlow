import 'dart:math' as math;
import 'dart:ui';

import '../models/stroke.dart';

/// Recorta segmentos vectoriales; nunca une los extremos separados por el borrador.
class StrokeEraser {
  static List<Stroke> erase(
    Stroke stroke,
    Offset center,
    double radius, {
    bool split = false,
  }) {
    if (stroke.points.isEmpty) return [stroke];
    final radius2 = radius * radius;
    bool inside(StrokePoint point) =>
        (point.offset - center).distanceSquared < radius2;
    if (stroke.points.length == 1) {
      return inside(stroke.points.first) ? [] : [stroke];
    }
    final chunks = <List<StrokePoint>>[];
    var chunk = <StrokePoint>[];
    var hit = false;
    void finish() {
      if (chunk.isNotEmpty) chunks.add(chunk);
      chunk = [];
    }

    for (var index = 1; index < stroke.points.length; index++) {
      final start = stroke.points[index - 1];
      final end = stroke.points[index];
      final delta = end.offset - start.offset;
      final offset = start.offset - center;
      final a = delta.distanceSquared;
      final b = 2 * (offset.dx * delta.dx + offset.dy * delta.dy);
      final c = offset.distanceSquared - radius2;
      final cuts = <double>[0, 1];
      final discriminant = b * b - 4 * a * c;
      if (a > 0 && discriminant > 0) {
        for (final t in [
          (-b - math.sqrt(discriminant)) / (2 * a),
          (-b + math.sqrt(discriminant)) / (2 * a),
        ]) {
          if (t > 0 && t < 1) cuts.add(t);
        }
      }
      cuts.sort();
      StrokePoint at(double t) => StrokePoint(
        x: start.x + (end.x - start.x) * t,
        y: start.y + (end.y - start.y) * t,
        pressure: start.pressure + (end.pressure - start.pressure) * t,
        tilt: start.tilt + (end.tilt - start.tilt) * t,
        timestamp: (start.timestamp + (end.timestamp - start.timestamp) * t)
            .round(),
      );
      for (var i = 1; i < cuts.length; i++) {
        if (inside(at((cuts[i - 1] + cuts[i]) / 2))) {
          hit = true;
          if (!split) return [];
          finish();
        } else {
          if (chunk.isEmpty) chunk.add(at(cuts[i - 1]));
          chunk.add(at(cuts[i]));
        }
      }
    }
    finish();
    if (!hit) return [stroke];
    return [
      for (var i = 0; i < chunks.length; i++)
        stroke.copyWith(id: '${stroke.id}-cut-$i', points: chunks[i]),
    ];
  }
}
