import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pdf/pdf.dart' as p;
import 'package:pdf/widgets.dart' as pw;

import '../../canvas/models/canvas_image.dart';
import '../../canvas/models/placed_sticker.dart';
import '../../canvas/models/stroke.dart';
import '../../canvas/models/text_annotation.dart';
import '../../canvas/painters/canvas_painter.dart';

/// Exportación local fiel al lienzo. Los PDF del lienzo incrustan cada página a 108 dpi.
class ExportService {
  Future<File> exportCanvasToPdf({
    required String outputPath,
    required List<Stroke> strokes,
    List<TextAnnotation> textAnnotations = const [],
    List<PlacedSticker> stickers = const [],
    List<CanvasImage> images = const [],
    Color paperColor = Colors.white,
    String templateId = 'blank',
    Size canvasSize = const Size(820, 1160),
    Rect? canvasBounds,
    bool paginate = false,
  }) async {
    final bounds = canvasBounds ?? (Offset.zero & canvasSize);
    const tile = Size(820, 1160);
    final columns = paginate ? (bounds.width / tile.width).ceil() : 1;
    final rows = paginate ? (bounds.height / tile.height).ceil() : 1;
    if (columns * rows > 200) {
      throw ArgumentError(
        'La exportación supera 200 páginas. Divide la nota antes de exportar.',
      );
    }
    final document = pw.Document(title: 'InkFlow', creator: 'InkFlow offline');
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final pageBounds = paginate
            ? Rect.fromLTWH(
                bounds.left + column * tile.width,
                bounds.top + row * tile.height,
                tile.width,
                tile.height,
              )
            : bounds;
        final png = await renderCanvas(
          strokes: strokes,
          textAnnotations: textAnnotations,
          stickers: stickers,
          images: images,
          paperColor: paperColor,
          templateId: templateId,
          canvasBounds: pageBounds,
          pixelRatio: 1.5,
        );
        document.addPage(
          pw.Page(
            pageFormat: p.PdfPageFormat(
              pageBounds.width,
              pageBounds.height,
              marginAll: 0,
            ),
            build: (_) => pw.Image(
              pw.MemoryImage(png),
              width: pageBounds.width,
              height: pageBounds.height,
            ),
          ),
        );
      }
    }
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    return file.writeAsBytes(await document.save(), flush: true);
  }

  Future<File> exportEditorToPdf({
    required String outputPath,
    required Map<String, dynamic> editorJson,
  }) async {
    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/FiraCode-Regular.ttf'),
    );
    final document = pw.Document();
    final markdown = convertEditorJsonToMarkdown(editorJson);
    document.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: font),
        build: (_) => markdown
            .split('\n')
            .map(
              (line) => pw.Text(
                line.isEmpty ? ' ' : line,
                style: const pw.TextStyle(fontSize: 11),
              ),
            )
            .toList(),
      ),
    );
    return File(outputPath).writeAsBytes(await document.save(), flush: true);
  }

  Future<File> exportCanvasToPng({
    required String outputPath,
    required List<Stroke> strokes,
    List<TextAnnotation> textAnnotations = const [],
    List<PlacedSticker> stickers = const [],
    List<CanvasImage> images = const [],
    Color paperColor = Colors.white,
    String templateId = 'blank',
    bool transparentBackground = false,
    Size canvasSize = const Size(820, 1160),
    Rect? canvasBounds,
    double pixelRatio = 2,
  }) async {
    final bytes = await renderCanvas(
      strokes: strokes,
      textAnnotations: textAnnotations,
      stickers: stickers,
      images: images,
      paperColor: paperColor,
      templateId: templateId,
      transparentBackground: transparentBackground,
      canvasSize: canvasSize,
      canvasBounds: canvasBounds,
      pixelRatio: pixelRatio,
    );
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    return file.writeAsBytes(bytes, flush: true);
  }

  Future<Uint8List> renderCanvas({
    required List<Stroke> strokes,
    List<TextAnnotation> textAnnotations = const [],
    List<PlacedSticker> stickers = const [],
    List<CanvasImage> images = const [],
    Color paperColor = Colors.white,
    String templateId = 'blank',
    bool transparentBackground = false,
    Size canvasSize = const Size(820, 1160),
    Rect? canvasBounds,
    double pixelRatio = 2,
  }) async {
    final bounds = canvasBounds ?? (Offset.zero & canvasSize);
    canvasSize = bounds.size;
    if (canvasBounds != null && !canvasSize.isEmpty) {
      pixelRatio = math.min(
        pixelRatio,
        math.min(
          16000 / math.max(canvasSize.width, canvasSize.height),
          math.sqrt(16000000 / (canvasSize.width * canvasSize.height)),
        ),
      );
    }
    if (!canvasSize.width.isFinite ||
        !canvasSize.height.isFinite ||
        canvasSize.isEmpty ||
        !pixelRatio.isFinite ||
        pixelRatio <= 0 ||
        canvasSize.width * canvasSize.height * pixelRatio * pixelRatio >
            32000000) {
      throw ArgumentError(
        'El tamaño de exportación no es válido o supera 32 megapíxeles.',
      );
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    canvas.clipRect(Offset.zero & canvasSize);
    canvas.translate(-bounds.left, -bounds.top);
    final resources = <ui.Image>[];
    Future<void> drawImage(
      String path,
      Offset position,
      Size size,
      double rotation,
    ) async {
      final codec = await ui.instantiateImageCodec(
        await File(path).readAsBytes(),
      );
      try {
        final image = (await codec.getNextFrame()).image;
        resources.add(image);
        canvas.save();
        canvas.translate(
          position.dx + size.width / 2,
          position.dy + size.height / 2,
        );
        canvas.rotate(rotation);
        final fit = applyBoxFit(
          BoxFit.contain,
          Size(image.width.toDouble(), image.height.toDouble()),
          size,
        );
        canvas.drawImageRect(
          image,
          Alignment.center.inscribe(
            fit.source,
            Rect.fromLTWH(
              0,
              0,
              image.width.toDouble(),
              image.height.toDouble(),
            ),
          ),
          Alignment.center.inscribe(
            fit.destination,
            Rect.fromCenter(
              center: Offset.zero,
              width: size.width,
              height: size.height,
            ),
          ),
          Paint(),
        );
        canvas.restore();
      } finally {
        codec.dispose();
      }
    }

    ui.Picture? picture;
    ui.Image? raster;
    try {
      // El mismo pintor conserva presión, suavizado, plantilla y tipografía.
      CanvasPainter(
        strokes: const [],
        templateId: templateId,
        visibleRect: bounds,
        paperColor: transparentBackground ? Colors.transparent : paperColor,
      ).paint(canvas, canvasSize);
      for (final image in images) {
        await drawImage(
          image.filePath,
          image.position,
          Size(image.width * image.scale, image.height * image.scale),
          image.rotation,
        );
      }
      CanvasPainter(
        strokes: strokes,
        textAnnotations: textAnnotations,
        templateId: 'blank',
        paperColor: Colors.transparent,
      ).paint(canvas, canvasSize);
      for (final sticker in stickers) {
        final size = Size(
          sticker.size.width * sticker.scale,
          sticker.size.height * sticker.scale,
        );
        if (sticker.assetPath != null ||
            (sticker.filePath?.toLowerCase().endsWith('.svg') ?? false)) {
          final source = sticker.assetPath != null
              ? await rootBundle.loadString(sticker.assetPath!)
              : await File(sticker.filePath!).readAsString();
          final info = await vg.loadPicture(SvgStringLoader(source), null);
          try {
            final factor = math.min(
              size.width / info.size.width,
              size.height / info.size.height,
            );
            canvas.save();
            canvas.translate(
              sticker.position.dx + size.width / 2,
              sticker.position.dy + size.height / 2,
            );
            canvas.rotate(sticker.rotation);
            canvas.scale(factor);
            canvas.translate(-info.size.width / 2, -info.size.height / 2);
            canvas.drawPicture(info.picture);
            canvas.restore();
          } finally {
            info.picture.dispose();
          }
        } else if (sticker.filePath != null) {
          await drawImage(
            sticker.filePath!,
            sticker.position,
            size,
            sticker.rotation,
          );
        }
      }
      picture = recorder.endRecording();
      raster = await picture.toImage(
        (canvasSize.width * pixelRatio).ceil(),
        (canvasSize.height * pixelRatio).ceil(),
      );
      final bytes = await raster.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('No se pudo codificar el PNG.');
      return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    } finally {
      if (recorder.isRecording) recorder.endRecording().dispose();
      raster?.dispose();
      picture?.dispose();
      for (final image in resources) {
        image.dispose();
      }
    }
  }

  /// Serializa el contenido de un documento estructurado de AppFlowy a Markdown estándar.
  String convertEditorJsonToMarkdown(Map<String, dynamic> documentJson) {
    final buffer = StringBuffer();

    try {
      final children =
          documentJson['document']?['children'] as List<dynamic>? ??
          documentJson['children'] as List<dynamic>? ??
          [];

      for (final child in children) {
        if (child is! Map<String, dynamic>) continue;
        _renderNodeToMarkdown(child, buffer);
      }
    } catch (e) {
      debugPrint('Error al convertir JSON a Markdown: $e');
    }

    return buffer.toString().trim();
  }

  void _renderNodeToMarkdown(
    Map<String, dynamic> node,
    StringBuffer buffer, {
    int depth = 0,
  }) {
    final type = node['type'] as String? ?? 'paragraph';
    final data = node['data'] as Map<String, dynamic>? ?? {};

    // Extracción de texto delta
    String textContent = '';
    final delta = data['delta'] as List<dynamic>?;
    if (delta != null) {
      for (final op in delta) {
        if (op is Map<String, dynamic> && op['insert'] is String) {
          var text = op['insert'] as String;
          final attributes = op['attributes'] as Map? ?? {};
          if (type != 'code') {
            if (attributes['code'] == true) text = '`$text`';
            if (attributes['bold'] == true) text = '**$text**';
            if (attributes['italic'] == true) text = '*$text*';
            if (attributes['href'] is String) {
              text = '[$text](${attributes['href']})';
            }
          }
          textContent += text;
        }
      }
    } else if (data['text'] != null) {
      textContent = data['text'].toString();
    }

    final cleanText = textContent.trimRight();

    if (type == 'table') {
      final rows = (data['rowsLen'] as num?)?.toInt() ?? 0;
      final columns = (data['colsLen'] as num?)?.toInt() ?? 0;
      final cells = node['children'] as List? ?? [];
      for (var row = 0; row < rows; row++) {
        final values = <String>[];
        for (var col = 0; col < columns; col++) {
          final cell = cells
              .cast<Map>()
              .where(
                (v) =>
                    v['data']?['rowPosition'] == row &&
                    v['data']?['colPosition'] == col,
              )
              .firstOrNull;
          final content = StringBuffer();
          for (final child in cell?['children'] as List? ?? []) {
            _renderNodeToMarkdown(
              Map<String, dynamic>.from(child as Map),
              content,
            );
          }
          values.add(
            content
                .toString()
                .trim()
                .replaceAll('|', r'\|')
                .replaceAll('\n', '<br>'),
          );
        }
        buffer.writeln('| ${values.join(' | ')} |');
        if (row == 0) {
          buffer.writeln('| ${List.filled(columns, '---').join(' | ')} |');
        }
      }
      buffer.writeln();
      return;
    }

    switch (type) {
      case 'heading':
        final level = (data['level'] as num?)?.toInt() ?? 1;
        final hashes = '#' * level.clamp(1, 6);
        buffer.writeln('$hashes $cleanText\n');
        break;
      case 'bulleted_list':
        final indent = '  ' * depth;
        buffer.writeln('$indent- $cleanText');
        break;
      case 'numbered_list':
        final indent = '  ' * depth;
        buffer.writeln('${indent}1. $cleanText');
        break;
      case 'todo_list':
        final indent = '  ' * depth;
        final checked = data['checked'] == true;
        final mark = checked ? '[x]' : '[ ]';
        buffer.writeln('$indent- $mark $cleanText');
        break;
      case 'quote':
        buffer.writeln('> $cleanText\n');
        break;
      case 'divider':
        buffer.writeln('---\n');
        break;
      case 'code':
        final lang = data['language'] as String? ?? '';
        buffer.writeln('```$lang\n$cleanText\n```\n');
        break;
      case 'paragraph':
      default:
        if (cleanText.isNotEmpty) {
          buffer.writeln('$cleanText\n');
        }
        break;
    }

    // Procesar nodos hijos
    final children = node['children'] as List<dynamic>?;
    if (children != null) {
      for (final child in children) {
        if (child is Map<String, dynamic>) {
          _renderNodeToMarkdown(child, buffer, depth: depth + 1);
        }
      }
    }
  }

  /// Guarda una cadena Markdown en un archivo en disco.
  Future<File> exportMarkdownToFile({
    required String outputPath,
    required String markdownContent,
  }) async {
    final file = File(outputPath);
    await file.writeAsString(markdownContent);
    return file;
  }
}
