import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/database_provider.dart';
import '../../../backup/services/backup_service.dart';
import '../../../canvas/models/canvas_image.dart';
import '../../../canvas/models/placed_sticker.dart';
import '../../../canvas/models/stroke.dart';
import '../../../canvas/models/text_annotation.dart';
import '../../services/export_service.dart';

typedef PdfExporter = Future<File> Function(String path);

class ExportDialog extends ConsumerStatefulWidget {
  final String pageTitle;
  final bool backupOnly;
  final List<Stroke>? strokes;
  final List<TextAnnotation>? textAnnotations;
  final List<PlacedSticker>? stickers;
  final List<CanvasImage>? images;
  final Map<String, dynamic>? editorJson;
  final Color paperColor;
  final String templateId;
  final Size canvasSize;
  final Rect? canvasBounds;
  final bool paginateCanvas;
  final PdfExporter? pdfExporter;
  const ExportDialog({
    super.key,
    required this.pageTitle,
    this.strokes,
    this.textAnnotations,
    this.stickers,
    this.images,
    this.editorJson,
    this.paperColor = Colors.white,
    this.templateId = 'blank',
    this.canvasSize = const Size(820, 1160),
    this.pdfExporter,
    this.canvasBounds,
    this.paginateCanvas = false,
    this.backupOnly = false,
  });
  @override
  ConsumerState<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<ExportDialog> {
  final _service = ExportService();
  bool _busy = false;
  String? _error;
  Future<void> _save(
    String ext,
    Future<File> Function(String) generate, {
    String? title,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    Directory? scratch;
    try {
      scratch = await Directory.systemTemp.createTemp('inkflow_export_');
      final generated = await generate('${scratch.path}/export.$ext');
      final bytes = await generated.readAsBytes();
      final name = (title ?? widget.pageTitle).replaceAll(
        RegExp(r'[<>:"/\\|?*\x00-\x1f]'),
        '_',
      );
      final output = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar exportación',
        fileName: '$name.$ext',
        type: FileType.custom,
        allowedExtensions: [ext],
        bytes: bytes,
      );
      if (!mounted || output == null) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Archivo guardado en $output')),
      );
    } catch (error) {
      if (mounted) setState(() => _error = 'No se pudo exportar: $error');
    } finally {
      if (scratch != null && await scratch.exists()) {
        await scratch.delete(recursive: true);
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<File> _pdf(String output) async {
    if (widget.pdfExporter != null) return widget.pdfExporter!(output);
    if (widget.editorJson != null) {
      return _service.exportEditorToPdf(
        outputPath: output,
        editorJson: widget.editorJson!,
      );
    }
    return _service.exportCanvasToPdf(
      outputPath: output,
      strokes: widget.strokes ?? [],
      images: widget.images ?? [],
      stickers: widget.stickers ?? [],
      textAnnotations: widget.textAnnotations ?? [],
      paperColor: widget.paperColor,
      templateId: widget.templateId,
      canvasSize: widget.canvasSize,
      canvasBounds: widget.canvasBounds,
      paginate: widget.paginateCanvas,
    );
  }

  Future<File> _png(String output, bool transparent) =>
      _service.exportCanvasToPng(
        outputPath: output,
        strokes: widget.strokes ?? [],
        images: widget.images ?? [],
        stickers: widget.stickers ?? [],
        textAnnotations: widget.textAnnotations ?? [],
        paperColor: widget.paperColor,
        templateId: widget.templateId,
        canvasSize: widget.canvasSize,
        canvasBounds: widget.canvasBounds,
        transparentBackground: transparent,
      );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(
        'Exportar: ${widget.pageTitle}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: _busy
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Preparando archivo…'),
                    ],
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null)
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (!widget.backupOnly)
                      ListTile(
                        leading: const Icon(Icons.picture_as_pdf_outlined),
                        title: const Text('Documento PDF'),
                        subtitle: Text(
                          widget.pdfExporter != null
                              ? 'Documento original con todas sus anotaciones'
                              : 'Contenido completo para compartir o imprimir',
                        ),
                        onTap: () => _save('pdf', _pdf),
                      ),
                    if (!widget.backupOnly &&
                        widget.editorJson == null &&
                        widget.pdfExporter == null) ...[
                      ListTile(
                        leading: const Icon(Icons.image_outlined),
                        title: const Text('Imagen PNG'),
                        subtitle: const Text(
                          'Incluye imágenes, stickers y plantilla',
                        ),
                        onTap: () => _save('png', (path) => _png(path, false)),
                      ),
                      ListTile(
                        leading: const Icon(Icons.hide_image_outlined),
                        title: const Text('PNG transparente'),
                        onTap: () => _save('png', (path) => _png(path, true)),
                      ),
                    ],
                    if (widget.editorJson != null)
                      ListTile(
                        leading: const Icon(Icons.code),
                        title: const Text('Markdown (.md)'),
                        onTap: () => _save(
                          'md',
                          (path) => _service.exportMarkdownToFile(
                            outputPath: path,
                            markdownContent: _service
                                .convertEditorJsonToMarkdown(
                                  widget.editorJson!,
                                ),
                          ),
                        ),
                      ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.archive_outlined),
                      title: const Text('Respaldo completo (.inkflow)'),
                      subtitle: const Text(
                        'Cuadernos, notas, base de datos y adjuntos',
                      ),
                      onTap: () => _save(
                        'inkflow',
                        (path) =>
                            BackupService(database: ref.read(databaseProvider))
                                .createBackup(destinationZipPath: path),
                        title: 'InkFlow_Respaldo',
                      ),
                    ),
                  ],
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}
