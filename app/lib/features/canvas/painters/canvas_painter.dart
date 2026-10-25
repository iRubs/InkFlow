import 'dart:math';

import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

import '../models/stroke.dart';
import '../models/text_annotation.dart';

/// Pintor principal de alto rendimiento para el lienzo de InkFlow.
///
/// Soporta:
/// - Múltiples estilos de lápiz/stylus (bolígrafo, pluma caligráfica, lápiz, pincel, resaltador).
/// - Plantillas de papel completas (rayado con margen, cuadrícula de ingeniería, punteado, Cornell, blanco).
/// - Visualización de lazo de selección activo con manipuladores de transformación.
/// - Regla virtual acrílica con marcas métricas e indicador de inclinación.
/// - Modo página física fija (A4 con sombra) y modo lienzo infinito.
class CanvasPainter extends CustomPainter {
  static final Expando<(int, Path)> _outlines = Expando('stroke outlines');
  final Matrix4? viewTransform;
  final Rect? visibleRect;
  final List<Stroke> strokes;
  final Stroke? activeStroke;
  final String templateId; // 'blank', 'ruled', 'grid', 'dotted', 'cornell'
  final Color paperColor;
  final Color gridColor;

  // Lazo de selección
  final List<Offset>? lassoPolygon;
  final Set<String>? selectedStrokeIds;
  final Rect? selectionBoundingBox;

  // Regla virtual
  final bool showRuler;
  final Offset rulerPosition;
  final double rulerAngle; // En radianes
  final double rulerLength;

  // Modo de página
  final bool isFixedPage;
  final bool isVerticalPage;
  final Size pageSize; // Ej. A4 (794 x 1123 pt)

  // Anotaciones de texto y fuente bonita
  final List<TextAnnotation> textAnnotations;

  CanvasPainter({
    required this.strokes,
    this.viewTransform,
    this.visibleRect,
    this.activeStroke,
    this.textAnnotations = const [],
    this.templateId = 'ruled',
    this.paperColor = Colors.white,
    this.gridColor = const Color(0xFFE2E8F0),
    this.lassoPolygon,
    this.selectedStrokeIds,
    this.selectionBoundingBox,
    this.showRuler = false,
    this.rulerPosition = const Offset(120, 240),
    this.rulerAngle = 0.0,
    this.rulerLength = 400.0,
    this.isFixedPage = false,
    this.isVerticalPage = false,
    this.pageSize = const Size(820, 1160),
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (viewTransform != null) canvas.transform(viewTransform!.storage);
    final visible = visibleRect ?? (Offset.zero & size);
    final effectiveRect = isFixedPage
        ? Offset.zero & pageSize
        : isVerticalPage
        ? Rect.fromLTRB(
            0,
            max(0, visible.top),
            pageSize.width,
            max(0, visible.bottom),
          )
        : visible;

    // 1. En modo página fija, dibujar sombra exterior del papel
    if (isFixedPage) {
      final pageRect = Offset.zero & pageSize;
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawRect(pageRect.shift(const Offset(4, 6)), shadowPaint);

      // Fondo de la hoja física
      final paperPaint = Paint()..color = paperColor;
      canvas.drawRect(pageRect, paperPaint);

      // Borde sutil del papel
      final borderPaint = Paint()
        ..color = gridColor.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRect(pageRect, borderPaint);
    } else {
      // Modo lienzo infinito
      final bgPaint = Paint()..color = paperColor;
      canvas.drawRect(isVerticalPage ? effectiveRect : visible, bgPaint);
    }

    if (isVerticalPage) {
      canvas.clipRect(
        Rect.fromLTWH(
          0,
          0,
          pageSize.width,
          max(pageSize.height, visible.bottom),
        ),
      );
    }
    // 2. Dibujar plantilla de papel seleccionada
    _drawTemplate(canvas, effectiveRect);

    // 3. Dibujar trazos guardados
    for (final stroke in strokes) {
      final isSelected = selectedStrokeIds?.contains(stroke.id) ?? false;
      _drawSingleStroke(canvas, stroke, isSelected: isSelected);
    }

    // 4. Dibujar anotaciones de texto y fuente bonita
    for (final annotation in textAnnotations) {
      _drawTextAnnotation(canvas, annotation);
    }

    // 5. Dibujar trazo en tiempo real
    if (activeStroke != null && activeStroke!.points.isNotEmpty) {
      _drawSingleStroke(canvas, activeStroke!);
    }

    // 6. Dibujar contorno de lazo mientras el usuario lo traza
    if (lassoPolygon != null && lassoPolygon!.length > 1) {
      _drawLassoInProgress(canvas);
    }

    // 6. Dibujar caja de selección de lazo activa
    if (selectionBoundingBox != null && selectionBoundingBox != Rect.zero) {
      _drawSelectionBox(canvas, selectionBoundingBox!);
    }

    // 7. Dibujar regla virtual interactiva si está activada
    if (showRuler) {
      _drawRuler(canvas);
    }
    canvas.restore();
  }

  void _drawTemplate(Canvas canvas, Rect area) {
    final linePaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    switch (templateId) {
      case 'ruled':
        const double lineSpacing = 32.0;
        const double startY = 80.0;
        for (
          double y =
              startY + ((area.top - startY) / lineSpacing).ceil() * lineSpacing;
          y < area.bottom;
          y += lineSpacing
        ) {
          canvas.drawLine(
            Offset(area.left, y),
            Offset(area.right, y),
            linePaint,
          );
        }
        // Margen lateral izquierdo rojo/rosado
        final marginPaint = Paint()
          ..color = const Color(0xFFFCA5A5)
          ..strokeWidth = 1.2;
        canvas.drawLine(
          Offset(80, area.top),
          Offset(80, area.bottom),
          marginPaint,
        );
        break;

      case 'grid':
        const double gridSize = 24.0;
        for (
          double x = (area.left / gridSize).floor() * gridSize;
          x < area.right;
          x += gridSize
        ) {
          canvas.drawLine(
            Offset(x, area.top),
            Offset(x, area.bottom),
            linePaint,
          );
        }
        for (
          double y = (area.top / gridSize).floor() * gridSize;
          y < area.bottom;
          y += gridSize
        ) {
          canvas.drawLine(
            Offset(area.left, y),
            Offset(area.right, y),
            linePaint,
          );
        }
        break;

      case 'dotted':
        const double dotSpacing = 24.0;
        final dotPaint = Paint()..color = gridColor;
        for (
          double x = (area.left / dotSpacing).ceil() * dotSpacing;
          x < area.right;
          x += dotSpacing
        ) {
          for (
            double y = (area.top / dotSpacing).ceil() * dotSpacing;
            y < area.bottom;
            y += dotSpacing
          ) {
            canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
          }
        }
        break;

      case 'cornell':
        // Plantilla académica Cornell Notes
        const double headerHeight = 70.0;
        const double cuesColumnWidth = 190.0;
        final double summaryTop = pageSize.height - 140.0;

        final dividerPaint = Paint()
          ..color = gridColor.withValues(alpha: 0.9)
          ..strokeWidth = 1.8;

        // Línea horizontal de encabezado
        canvas.drawLine(
          const Offset(0, headerHeight),
          Offset(pageSize.width, headerHeight),
          dividerPaint,
        );

        // Línea vertical separadora de columna de pistas/preguntas (Cues)
        canvas.drawLine(
          const Offset(cuesColumnWidth, headerHeight),
          Offset(cuesColumnWidth, summaryTop),
          dividerPaint,
        );

        // Línea horizontal de sección de resumen (Summary)
        canvas.drawLine(
          Offset(0, summaryTop),
          Offset(pageSize.width, summaryTop),
          dividerPaint,
        );

        // Renglones en el área principal de notas (a la derecha de la columna Cues)
        const double noteLineSpacing = 28.0;
        for (
          double y = headerHeight + noteLineSpacing;
          y < summaryTop;
          y += noteLineSpacing
        ) {
          canvas.drawLine(
            Offset(cuesColumnWidth, y),
            Offset(area.right, y),
            linePaint,
          );
        }
        break;

      case 'blank':
      default:
        break;
    }
  }

  void _drawSingleStroke(
    Canvas canvas,
    Stroke stroke, {
    bool isSelected = false,
  }) {
    if (stroke.points.isEmpty) return;

    if (stroke.tool == DrawingToolType.eraser ||
        stroke.tool == DrawingToolType.pixelEraser) {
      return;
    }

    final isHighlighter = stroke.tool == DrawingToolType.highlighter;
    final isFountainPen = stroke.tool == DrawingToolType.fountainPen;
    final isPencil = stroke.tool == DrawingToolType.pencil;
    final isBrush = stroke.tool == DrawingToolType.brush;

    Color strokeColor = stroke.color;
    if (isHighlighter) {
      strokeColor = stroke.color.withValues(alpha: 0.35);
    } else if (isPencil) {
      strokeColor = stroke.color.withValues(alpha: 0.85);
    }

    if (isSelected) {
      // Trazos seleccionados con lazo se resaltan en tono cian vibrante
      strokeColor = const Color(0xFF0284C7);
    }

    final paint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill;

    final cached = _outlines[stroke];
    if (cached != null && cached.$1 == stroke.points.length) {
      canvas.drawPath(cached.$2, paint);
      return;
    }

    // Convertir puntos a PointVector para perfect_freehand
    final strokePoints = stroke.points.map((p) {
      return PointVector(p.x, p.y, p.pressure);
    }).toList();

    // Dinámica orgánica según herramienta
    double thinning = 0.4;
    double smoothing = 0.55;
    double streamline = 0.45;

    if (isFountainPen) {
      thinning = 0.82;
      smoothing = 0.60;
      streamline = 0.50;
    } else if (isHighlighter) {
      thinning = 0.0;
      smoothing = 0.40;
      streamline = 0.30;
    } else if (isPencil) {
      thinning = 0.25;
      smoothing = 0.45;
      streamline = 0.35;
    } else if (isBrush) {
      thinning = 0.70;
      smoothing = 0.70;
      streamline = 0.60;
    }

    final outlinePoints = getStroke(
      strokePoints,
      options: StrokeOptions(
        size: stroke.width,
        thinning: thinning,
        smoothing: smoothing,
        streamline: streamline,
        simulatePressure: false,
      ),
    );

    if (outlinePoints.isEmpty) return;

    final path = Path();
    path.moveTo(outlinePoints.first.dx, outlinePoints.first.dy);
    for (int i = 1; i < outlinePoints.length; i++) {
      path.lineTo(outlinePoints[i].dx, outlinePoints[i].dy);
    }
    path.close();
    _outlines[stroke] = (stroke.points.length, path);

    canvas.drawPath(path, paint);
  }

  void _drawLassoInProgress(Canvas canvas) {
    final lassoPaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(lassoPolygon!.first.dx, lassoPolygon!.first.dy);
    for (int i = 1; i < lassoPolygon!.length; i++) {
      path.lineTo(lassoPolygon![i].dx, lassoPolygon![i].dy);
    }

    // Dibujar línea punteada o translúcida
    canvas.drawPath(path, lassoPaint);

    final fillPaint = Paint()
      ..color = const Color(0xFF0284C7).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
  }

  void _drawSelectionBox(Canvas canvas, Rect box) {
    final borderPaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    canvas.drawRect(box, borderPaint);

    // Relleno sutil
    final fillPaint = Paint()
      ..color = const Color(0xFF0284C7).withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    canvas.drawRect(box, fillPaint);

    // Dibujar manipuladores circulares en las 4 esquinas
    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final handleBorder = Paint()
      ..color = const Color(0xFF0284C7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final corners = [
      box.topLeft,
      box.topRight,
      box.bottomLeft,
      box.bottomRight,
    ];

    for (final corner in corners) {
      canvas.drawCircle(corner, 5.0, handlePaint);
      canvas.drawCircle(corner, 5.0, handleBorder);
    }
  }

  void _drawRuler(Canvas canvas) {
    canvas.save();
    canvas.translate(rulerPosition.dx, rulerPosition.dy);
    canvas.rotate(rulerAngle);

    const rulerHeight = 64.0;
    final rRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, -rulerHeight / 2, rulerLength, rulerHeight),
      const Radius.circular(8),
    );

    // Cuerpo acrílico semitransparente
    final bodyPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.88)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rRect, bodyPaint);

    // Borde de la regla
    final edgePaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(rRect, edgePaint);

    // Borde guía superior coloreado para trazar líneas rectas
    final guidePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 2.0;
    canvas.drawLine(
      const Offset(0, -32.0),
      Offset(rulerLength, -rulerHeight / 2),
      guidePaint,
    );

    // Graduación métrica (milímetros y centímetros)
    final tickPaint = Paint()
      ..color = const Color(0xFF475569)
      ..strokeWidth = 1.0;

    const double mmStep = 4.0;
    for (double x = 16.0; x < rulerLength - 16.0; x += mmStep) {
      final int tickIndex = (x / mmStep).round();
      double tickHeight = 6.0;
      if (tickIndex % 10 == 0) {
        tickHeight = 16.0; // Marca de centímetro
      } else if (tickIndex % 5 == 0) {
        tickHeight = 10.0; // Marca de medio centímetro
      }

      canvas.drawLine(
        Offset(x, -rulerHeight / 2),
        Offset(x, -rulerHeight / 2 + tickHeight),
        tickPaint,
      );
    }

    // Indicador numérico de ángulo
    final degrees = (rulerAngle * 180 / pi).round();
    final textSpan = TextSpan(
      text: '$degrees°',
      style: const TextStyle(
        color: Color(0xFF1E293B),
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(rulerLength / 2 - textPainter.width / 2, 4),
    );

    canvas.restore();
  }

  void _drawTextAnnotation(Canvas canvas, TextAnnotation annotation) {
    final textSpan = TextSpan(
      text: annotation.text,
      style: TextStyle(
        fontFamily: annotation.fontFamily,
        fontSize: annotation.fontSize,
        color: annotation.color,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(annotation.position.dx, annotation.position.dy);
    if (annotation.rotation != 0.0) {
      canvas.rotate(annotation.rotation);
    }
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) => true;
}
