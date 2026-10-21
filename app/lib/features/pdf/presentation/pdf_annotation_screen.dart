import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;

import '../../../core/storage/atomic_json_store.dart';
import '../../../shared/providers/database_provider.dart';
import '../../../data/database/app_database.dart';
import '../../canvas/models/canvas_image.dart';
import '../../canvas/models/placed_sticker.dart';
import '../../canvas/models/stroke.dart';
import '../../canvas/models/text_annotation.dart';
import '../../canvas/painters/canvas_painter.dart';
import '../../canvas/presentation/widgets/sticker_sheet_modal.dart';
import '../../canvas/services/attachment_manager.dart';
import '../../export/presentation/widgets/export_dialog.dart';
import '../../export/services/export_service.dart';

/// Las anotaciones usan puntos PDF; no dependen del tamaño de pantalla ni del zoom.
class PdfAnnotationScreen extends ConsumerStatefulWidget {
  final Page page;
  final File? initialPdfFile;
  final bool autoLoad;
  final Directory? baseDirectory;
  const PdfAnnotationScreen({
    super.key,
    required this.page,
    this.initialPdfFile,
    this.autoLoad = true,
    this.baseDirectory,
  });
  @override
  ConsumerState<PdfAnnotationScreen> createState() =>
      _PdfAnnotationScreenState();
}

class _PdfAnnotationScreenState extends ConsumerState<PdfAnnotationScreen>
    with WidgetsBindingObserver {
  final _attachments = AttachmentManager();
  PdfDocument? _document;
  final _transform = TransformationController();
  int _number = 1;
  bool _loading = true;
  bool _changing = false;
  String? _error;
  Directory? _strokesDir;
  final List<Stroke> _strokes = [];
  final List<TextAnnotation> _text = [];
  final List<PlacedSticker> _stickers = [];
  final List<List<Stroke>> _undo = [];
  final List<List<Stroke>> _redo = [];
  Stroke? _active;
  int? _pointer;
  DrawingToolType _tool = DrawingToolType.highlighter;
  Color _color = Colors.amber;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.autoLoad || widget.initialPdfFile != null) {
      _init();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _transform.dispose();
    _document?.dispose();
    super.dispose();
  }

  @override
  Future<ui.AppExitResponse> didRequestAppExit() async {
    try {
      await _save();
      await AtomicJsonStore.flush();
      return ui.AppExitResponse.exit;
    } catch (_) {
      return ui.AppExitResponse.cancel;
    }
  }

  Future<void> _init() async {
    try {
      final docs =
          widget.baseDirectory ?? await getApplicationDocumentsDirectory();
      _strokesDir = Directory(p.join(docs.path, 'InkFlowData', 'strokes'));
      final file =
          widget.initialPdfFile ??
          await _attachments.getPdfFile(widget.page.id);
      if (file != null) await _open(file);
    } catch (error) {
      _error = 'No se pudo abrir el PDF: $error';
    }
    if (mounted) setState(() => _loading = false);
  }

  File _file(int number) =>
      File(p.join(_strokesDir!.path, '${widget.page.id}_p$number.json'));
  Future<void> _open(File file) async {
    await pdfrxFlutterInitialize();
    final document = await PdfDocument.openFile(file.path);
    if (!mounted) {
      await document.dispose();
      return;
    }
    final previous = _document;
    _document = document;
    _number = 1;
    await _load();
    await previous?.dispose();
  }

  Future<void> _pick() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (!mounted || result?.files.single.path == null) return;
      setState(() => _loading = true);
      final docs =
          widget.baseDirectory ?? await getApplicationDocumentsDirectory();
      _strokesDir = Directory(p.join(docs.path, 'InkFlowData', 'strokes'));
      final path = await _attachments.savePdfAttachment(
        widget.page.id,
        result!.files.single.path!,
      );
      if (path == null) throw StateError('No se pudo copiar el PDF.');
      await _open(File(path));
    } catch (error) {
      _error = 'No se pudo importar: $error';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _load() async {
    final data = await AtomicJsonStore.read(_file(_number));
    if (!mounted) return;
    setState(() {
      _strokes
        ..clear()
        ..addAll(
          (data?['strokes'] as List? ?? []).map(
            (v) => Stroke.fromJson(Map<String, dynamic>.from(v as Map)),
          ),
        );
      _text
        ..clear()
        ..addAll(
          (data?['textAnnotations'] as List? ?? []).map(
            (v) => TextAnnotation.fromJson(Map<String, dynamic>.from(v as Map)),
          ),
        );
      _stickers
        ..clear()
        ..addAll(
          (data?['stickers'] as List? ?? []).map(
            (v) => PlacedSticker.fromJson(Map<String, dynamic>.from(v as Map)),
          ),
        );
      _undo.clear();
      _redo.clear();
      _active = null;
    });
  }

  Future<void> _save() async {
    if (_strokesDir == null || _error != null) return;
    await AtomicJsonStore.write(_file(_number), {
      'version': 4,
      'coordinateSystem': 'pdf-points',
      'pdf_page_number': _number,
      'strokes': _strokes.map((v) => v.toJson()).toList(),
      'textAnnotations': _text.map((v) => v.toJson()).toList(),
      'stickers': _stickers.map((v) => v.toJson()).toList(),
    });
    if (widget.baseDirectory == null && mounted) {
      await recordPageEdit(ref, widget.page.id);
    }
  }

  void _saveOrReport() {
    _save().catchError((Object error) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar la anotación: $error');
      }
    });
  }

  Future<void> _change(int number) async {
    if (_changing ||
        _pointer != null ||
        number == _number ||
        number < 1 ||
        number > _document!.pages.length) {
      return;
    }
    setState(() => _changing = true);
    try {
      await _save();
      if (!mounted) return;
      _number = number;
      _transform.value = Matrix4.identity();
      await _load();
    } catch (error) {
      _error = 'No se pudo cambiar de página: $error';
    }
    if (mounted) setState(() => _changing = false);
  }

  bool _accept(PointerEvent event) =>
      event.kind == PointerDeviceKind.stylus ||
      event.kind == PointerDeviceKind.invertedStylus ||
      event.kind == PointerDeviceKind.mouse;
  void _down(PointerDownEvent event) {
    if (!_accept(event) || _pointer != null || _changing || _error != null) {
      return;
    }
    _undo.add(List.of(_strokes));
    _redo.clear();
    setState(() {
      _pointer = event.pointer;
      if (_tool != DrawingToolType.eraser) {
        _active = Stroke(
          id: 'pdf-${DateTime.now().microsecondsSinceEpoch}',
          tool: _tool,
          color: _color,
          width: _tool == DrawingToolType.highlighter ? 16 : 2.5,
          points: [_point(event)],
        );
      }
    });
    if (_tool == DrawingToolType.eraser) _erase(event.localPosition);
  }

  StrokePoint _point(PointerEvent event) => StrokePoint(
    x: event.localPosition.dx,
    y: event.localPosition.dy,
    pressure: event.pressure.clamp(0.05, 1.0),
    tilt: event.tilt,
    timestamp: event.timeStamp.inMilliseconds,
  );
  void _move(PointerMoveEvent event) {
    if (_pointer != event.pointer) return;
    if (_tool == DrawingToolType.eraser) {
      _erase(event.localPosition);
      return;
    }
    setState(() => _active?.points.add(_point(event)));
  }

  void _erase(Offset position) {
    setState(
      () => _strokes.removeWhere(
        (stroke) => stroke.points.any(
          (point) => (Offset(point.x, point.y) - position).distance < 16,
        ),
      ),
    );
  }

  void _up(PointerEvent event) {
    if (_pointer != event.pointer) return;
    setState(() {
      if (_active != null) _strokes.add(_active!);
      _active = null;
      _pointer = null;
    });
    _saveOrReport();
  }

  void _history(bool redo) {
    final from = redo ? _redo : _undo;
    final to = redo ? _undo : _redo;
    if (from.isEmpty) return;
    setState(() {
      to.add(List.of(_strokes));
      _strokes
        ..clear()
        ..addAll(from.removeLast());
    });
    _saveOrReport();
  }

  Future<File> _export(String output) async {
    await _save();
    final document = _document!;
    final result = pw.Document();
    final scratch = await Directory.systemTemp.createTemp(
      'inkflow_pdf_export_',
    );
    try {
      for (final page in document.pages) {
        final rendered = await page.render(
          fullWidth: page.width * 2,
          fullHeight: page.height * 2,
        );
        if (rendered == null) {
          throw StateError(
            'No se pudo renderizar la página ${page.pageNumber}.',
          );
        }
        final image = await rendered.createImage();
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final source = File(p.join(scratch.path, 'source.png'));
          await source.writeAsBytes(bytes!.buffer.asUint8List());
          final data = await AtomicJsonStore.read(_file(page.pageNumber));
          final png = await ExportService().renderCanvas(
            canvasSize: page.size,
            images: [
              CanvasImage(
                id: 'source',
                filePath: source.path,
                position: Offset.zero,
                width: page.width,
                height: page.height,
              ),
            ],
            strokes: (data?['strokes'] as List? ?? [])
                .map(
                  (v) => Stroke.fromJson(Map<String, dynamic>.from(v as Map)),
                )
                .toList(),
            textAnnotations: (data?['textAnnotations'] as List? ?? [])
                .map(
                  (v) => TextAnnotation.fromJson(
                    Map<String, dynamic>.from(v as Map),
                  ),
                )
                .toList(),
            stickers: (data?['stickers'] as List? ?? [])
                .map(
                  (v) => PlacedSticker.fromJson(
                    Map<String, dynamic>.from(v as Map),
                  ),
                )
                .toList(),
          );
          result.addPage(
            pw.Page(
              pageFormat: pdf.PdfPageFormat(
                page.width,
                page.height,
                marginAll: 0,
              ),
              build: (_) => pw.Image(
                pw.MemoryImage(png),
                width: page.width,
                height: page.height,
              ),
            ),
          );
        } finally {
          image.dispose();
          rendered.dispose();
        }
      }
      return await File(output).writeAsBytes(await result.save());
    } finally {
      await scratch.delete(recursive: true);
    }
  }

  void _addSticker() => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => StickerSheetModal(
      onStickerSelected: (item) {
        if (!mounted) return;
        setState(
          () => _stickers.add(
            PlacedSticker(
              id: 'pdf-sticker-${DateTime.now().microsecondsSinceEpoch}',
              assetPath: item.assetPath,
              filePath: item.filePath,
              position: const Offset(80, 80),
            ),
          ),
        );
        _saveOrReport();
      },
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.page.title, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          tooltip: 'Deshacer',
          icon: const Icon(Icons.undo),
          onPressed: _undo.isEmpty ? null : () => _history(false),
        ),
        IconButton(
          tooltip: 'Rehacer',
          icon: const Icon(Icons.redo),
          onPressed: _redo.isEmpty ? null : () => _history(true),
        ),
        IconButton(
          tooltip: 'Exportar PDF completo',
          icon: const Icon(Icons.ios_share_rounded),
          onPressed: _document == null || _error != null
              ? null
              : () => showDialog(
                  context: context,
                  builder: (_) => ExportDialog(
                    pageTitle: widget.page.title,
                    pdfExporter: _export,
                  ),
                ),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText(_error!),
            ),
          )
        : _document == null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.picture_as_pdf_outlined, size: 72),
                  const SizedBox(height: 16),
                  const Text(
                    'Ningún archivo PDF vinculado a esta página',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _pick,
                    icon: const Icon(Icons.file_open_rounded),
                    label: const Text('Importar Archivo PDF'),
                  ),
                ],
              ),
            ),
          )
        : Column(
            children: [
              Expanded(
                child: _changing
                    ? const Center(child: CircularProgressIndicator())
                    : InteractiveViewer(
                        transformationController: _transform,
                        minScale: 1,
                        maxScale: 6,
                        panEnabled: _pointer == null,
                        scaleEnabled: _pointer == null,
                        child: Center(
                          child: FittedBox(
                            child: SizedBox(
                              width: _document!.pages[_number - 1].width,
                              height: _document!.pages[_number - 1].height,
                              child: Listener(
                                key: const ValueKey('pdf-ink-input'),
                                onPointerDown: _down,
                                onPointerMove: _move,
                                onPointerUp: _up,
                                onPointerCancel: _up,
                                behavior: HitTestBehavior.opaque,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    PdfPageView(
                                      document: _document,
                                      pageNumber: _number,
                                    ),
                                    IgnorePointer(
                                      child: CustomPaint(
                                        painter: CanvasPainter(
                                          strokes: _strokes,
                                          activeStroke: _active,
                                          textAnnotations: _text,
                                          templateId: 'blank',
                                          paperColor: Colors.transparent,
                                        ),
                                      ),
                                    ),
                                    for (final sticker in _stickers)
                                      Positioned(
                                        left: sticker.position.dx,
                                        top: sticker.position.dy,
                                        width:
                                            sticker.size.width * sticker.scale,
                                        height:
                                            sticker.size.height * sticker.scale,
                                        child: IgnorePointer(
                                          child: sticker.assetPath != null
                                              ? SvgPicture.asset(
                                                  sticker.assetPath!,
                                                )
                                              : sticker.filePath!.endsWith(
                                                  '.svg',
                                                )
                                              ? SvgPicture.file(
                                                  File(sticker.filePath!),
                                                )
                                              : Image.file(
                                                  File(sticker.filePath!),
                                                ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              SafeArea(
                top: false,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final tool in [
                        DrawingToolType.highlighter,
                        DrawingToolType.pen,
                        DrawingToolType.eraser,
                      ])
                        IconButton(
                          isSelected: _tool == tool,
                          tooltip: tool == DrawingToolType.pen
                              ? 'Bolígrafo'
                              : tool == DrawingToolType.eraser
                              ? 'Borrador'
                              : 'Resaltador',
                          onPressed: () => setState(() => _tool = tool),
                          icon: Icon(
                            tool == DrawingToolType.pen
                                ? Icons.edit
                                : tool == DrawingToolType.eraser
                                ? Icons.auto_fix_normal
                                : Icons.border_color,
                          ),
                        ),
                      for (final color in [
                        Colors.amber,
                        Colors.blue,
                        Colors.red,
                        Colors.black,
                      ])
                        IconButton(
                          tooltip:
                              'Color ${color.toARGB32().toRadixString(16)}',
                          onPressed: () => setState(() => _color = color),
                          icon: Icon(Icons.circle, color: color),
                        ),
                      IconButton(
                        tooltip: 'Insertar sticker',
                        onPressed: _addSticker,
                        icon: const Icon(Icons.emoji_emotions_outlined),
                      ),
                      IconButton(
                        tooltip: 'Página anterior',
                        onPressed: _number > 1
                            ? () => _change(_number - 1)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text('Página $_number de ${_document!.pages.length}'),
                      IconButton(
                        tooltip: 'Página siguiente',
                        onPressed: _number < _document!.pages.length
                            ? () => _change(_number + 1)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
  );
}
