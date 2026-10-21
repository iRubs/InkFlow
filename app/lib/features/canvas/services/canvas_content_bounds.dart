import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/canvas_image.dart';
import '../models/placed_sticker.dart';
import '../models/stroke.dart';
import '../models/text_annotation.dart';

/// Shared world-space bounds for framing and export, including negative space.
class CanvasContentBounds {
  static Rect compute({
    List<Stroke> strokes = const [],
    List<CanvasImage> images = const [],
    List<PlacedSticker> stickers = const [],
    List<TextAnnotation> text = const [],
  }) {
    Rect? result;
    void include(Rect rect) {
      if (!rect.isFinite) return;
      result = result == null ? rect : result!.expandToInclude(rect);
    }

    Rect rotated(Rect rect, double angle) {
      if (angle == 0) return rect;
      final width =
          rect.width * math.cos(angle).abs() +
          rect.height * math.sin(angle).abs();
      final height =
          rect.width * math.sin(angle).abs() +
          rect.height * math.cos(angle).abs();
      return Rect.fromCenter(center: rect.center, width: width, height: height);
    }

    for (final stroke in strokes) {
      if (stroke.points.isNotEmpty) {
        include(stroke.bounds.inflate(stroke.width));
      }
    }
    for (final image in images) {
      include(rotated(image.bounds, image.rotation));
    }
    for (final sticker in stickers) {
      include(rotated(sticker.bounds, sticker.rotation));
    }
    for (final annotation in text) {
      final painter = TextPainter(
        text: TextSpan(
          text: annotation.text,
          style: TextStyle(
            fontFamily: annotation.fontFamily,
            fontSize: annotation.fontSize,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final rect = annotation.position & painter.size;
      // Text rotates around its top-left anchor; the diagonal is conservative.
      if (annotation.rotation == 0) {
        include(rect);
      } else {
        final radius = math.sqrt(
          rect.width * rect.width + rect.height * rect.height,
        );
        include(Rect.fromCircle(center: annotation.position, radius: radius));
      }
      painter.dispose();
    }
    return result?.inflate(32) ?? const Rect.fromLTWH(0, 0, 820, 1160);
  }
}
