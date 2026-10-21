import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'stroke.dart';

/// Gestiona la selección interactiva por lazo de trazos en el lienzo de InkFlow.
class LassoSelection {
  static const _uuid = Uuid();
  final Set<String> selectedIds;

  const LassoSelection({required this.selectedIds});

  bool get isEmpty => selectedIds.isEmpty;
  bool get isNotEmpty => selectedIds.isNotEmpty;

  /// Algoritmo Ray-Casting para determinar si un punto se encuentra dentro de un polígono cerrado.
  static bool isPointInPolygon(Offset point, List<Offset> polygon) {
    if (polygon.length < 3) return false;
    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].dx, yi = polygon[i].dy;
      final xj = polygon[j].dx, yj = polygon[j].dy;
      final intersect =
          ((yi > point.dy) != (yj > point.dy)) &&
          (point.dx < (xj - xi) * (point.dy - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  /// Identifica qué trazos están contenidos o tocados por el lazo trazado por el usuario.
  static LassoSelection fromPolygon(
    List<Offset> polygon,
    List<Stroke> allStrokes,
  ) {
    if (polygon.length < 3 || allStrokes.isEmpty) {
      return const LassoSelection(selectedIds: {});
    }

    // Calcular bounding box del polígono de lazo
    double minX = polygon.first.dx;
    double maxX = polygon.first.dx;
    double minY = polygon.first.dy;
    double maxY = polygon.first.dy;

    for (final p in polygon) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    final lassoBounds = Rect.fromLTRB(minX, minY, maxX, maxY);

    final selected = <String>{};

    for (final stroke in allStrokes) {
      // Descarte rápido por bounding box
      if (!lassoBounds.overlaps(stroke.bounds)) continue;

      // Comprobación precisa punto por punto del trazo
      bool hit = false;
      for (final pt in stroke.points) {
        if (isPointInPolygon(Offset(pt.x, pt.y), polygon)) {
          hit = true;
          break;
        }
      }

      if (hit) {
        selected.add(stroke.id);
      }
    }

    return LassoSelection(selectedIds: selected);
  }

  /// Calcula la caja delimitadora que envuelve a todos los trazos seleccionados.
  Rect computeBoundingBox(List<Stroke> allStrokes) {
    final active = allStrokes.where((s) => selectedIds.contains(s.id)).toList();
    if (active.isEmpty) return Rect.zero;

    Rect combined = active.first.bounds;
    for (int i = 1; i < active.length; i++) {
      combined = combined.expandToInclude(active[i].bounds);
    }

    // Añadir margen cómodo para manipuladores
    return combined.inflate(8.0);
  }

  /// Aplica traslación a los trazos seleccionados
  List<Stroke> applyTranslation(List<Stroke> strokes, Offset delta) {
    return strokes.map((s) {
      if (selectedIds.contains(s.id)) {
        return s.translate(delta);
      }
      return s;
    }).toList();
  }

  /// Aplica escalado a los trazos seleccionados respecto al centro de su caja
  List<Stroke> applyScale(List<Stroke> strokes, double factor, Offset origin) {
    return strokes.map((s) {
      if (selectedIds.contains(s.id)) {
        return s.scale(factor, origin);
      }
      return s;
    }).toList();
  }

  /// Cambia el color de todos los trazos seleccionados
  List<Stroke> applyColor(List<Stroke> strokes, Color newColor) {
    return strokes.map((s) {
      if (selectedIds.contains(s.id)) {
        return s.changeColor(newColor);
      }
      return s;
    }).toList();
  }

  /// Duplica los trazos seleccionados desplazándolos ligeramente
  (List<Stroke> updatedStrokes, LassoSelection newSelection) duplicate(
    List<Stroke> strokes, {
    Offset offset = const Offset(24, 24),
  }) {
    final duplicated = <Stroke>[];
    final newIds = <String>{};

    for (final s in strokes) {
      if (selectedIds.contains(s.id)) {
        final newId = _uuid.v4();
        newIds.add(newId);
        duplicated.add(s.copyWith(id: newId).translate(offset));
      }
    }

    return ([...strokes, ...duplicated], LassoSelection(selectedIds: newIds));
  }

  /// Obtiene los trazos que están dentro de la selección activa ordenados cronológicamente
  List<Stroke> getSelectedStrokes(List<Stroke> allStrokes) {
    final list = allStrokes.where((s) => selectedIds.contains(s.id)).toList();
    list.sort((a, b) {
      final tA = a.points.isNotEmpty ? a.points.first.timestamp : 0;
      final tB = b.points.isNotEmpty ? b.points.first.timestamp : 0;
      return tA.compareTo(tB);
    });
    return list;
  }
}
