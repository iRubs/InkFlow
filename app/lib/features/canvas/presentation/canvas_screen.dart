import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:file_picker/file_picker.dart';

import '../../../core/storage/atomic_json_store.dart';
import '../../../shared/providers/database_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../data/database/app_database.dart';
import '../../export/presentation/widgets/export_dialog.dart';
import '../models/canvas_image.dart';
import '../models/lasso_selection.dart';
import '../models/placed_sticker.dart';
import '../models/stroke.dart';
import '../models/text_annotation.dart';
import '../painters/canvas_painter.dart';
import '../services/attachment_manager.dart';
import '../services/font_manager.dart';
import '../services/handwriting_recognition_service.dart';
import '../services/palette_manager.dart';
import '../services/shape_recognizer.dart';
import '../services/stroke_eraser.dart';
import '../services/sticker_manager.dart';
import 'widgets/advanced_color_picker_dialog.dart';
import 'widgets/infinite_canvas_viewport.dart';
import '../services/canvas_content_bounds.dart';
import 'widgets/sticker_sheet_modal.dart';

/// Pantalla avanzada del Lienzo de Dibujo y Escritura con Stylus / S Pen.
///
/// Características principales:
/// - Sensibilidad a presión (0.0 a 1.0) e inclinación con baja latencia.
/// - Rechazo de palma estricto (solo el S Pen dibuja; los dedos hacen pan/zoom).
/// - Detección del botón físico secundario del S Pen para alternar borrador al vuelo.
/// - Herramientas: Bolígrafo, Pluma, Lápiz, Pincel, Resaltador, Borrador por trazo, Borrador de píxeles, Lazo.
/// - Autocorrección matemática de formas geométricas (Línea, Círculo, Rectángulo, Triángulo, Flecha).
/// - Herramienta de Lazo: Selección libre, mover, duplicar, recolorear y eliminar trazos.
/// - Escritura a texto y "Fuente Bonita" con reconocimiento on-device.
/// - Paleta ilimitada HSV/HEX, colores recientes y herramienta Gotero (Eyedropper).
/// - Biblioteca de stickers libres, stickers personalizados y packs importables.
/// - Regla virtual acrílica con graduación métrica y ajuste de ángulo.
/// - Modos: Lienzo Infinito con zoom/pan fluido (0.25x - 5.0x) o Página Fija A4.
class CanvasScreen extends ConsumerStatefulWidget {
  final Page page;
  final Directory? baseDirectory;
  final List<Stroke>? initialStrokes;
  final List<TextAnnotation>? initialTextAnnotations;
  final List<PlacedSticker>? initialStickers;

  const CanvasScreen({
    super.key,
    required this.page,
    this.baseDirectory,
    this.initialStrokes,
    this.initialTextAnnotations,
    this.initialStickers,
  });

  @override
  ConsumerState<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends ConsumerState<CanvasScreen>
    with WidgetsBindingObserver {
  static const _uuid = Uuid();

  // Historial de trazos y deshacer/rehacer
  final List<Stroke> _strokes = [];
  final List<_CanvasSnapshot> _undoHistory = [];
  final List<_CanvasSnapshot> _redoHistory = [];
  _CanvasSnapshot? _lastSnapshot;
  Stroke? _currentStroke;

  // Anotaciones de texto y stickers en el lienzo
  final List<TextAnnotation> _textAnnotations = [];
  final List<PlacedSticker> _stickers = [];
  String? _selectedStickerId;

  // Gestión de imágenes interactivas sobre el lienzo
  final List<CanvasImage> _images = [];
  String? _selectedImageId;
  final AttachmentManager _attachmentManager = AttachmentManager();

  // Servicios de reconocimiento, paletas, fuentes y stickers
  final HandwritingRecognitionService _recognitionService =
      OfflineHandwritingService();
  final PaletteManager _paletteManager = PaletteManager();
  final FontManager _fontManager = FontManager();
  final StickerManager _stickerManager = StickerManager();

  // Estado de herramientas avanzadas
  bool _isEyedropperActive = false;
  String _selectedHandwritingFont = 'Caveat';
  final String _recognitionLanguage = 'es';

  // Controlador de matriz de transformación para zoom y pan fluidos
  final TransformationController _transformationController =
      TransformationController();

  // Configuración de herramienta activa
  DrawingToolType _activeTool = DrawingToolType.pen;
  Color _activeColor = InkColors.defaultInkPalette.first;
  double _activeWidth = 3.5;
  String _activeTemplate = 'ruled';

  // Opciones avanzadas de escritura
  bool _strictPalmRejection = true;
  bool _autoShapeCorrection = true;
  bool _isFixedPage = false;
  bool _showRuler = false;
  bool _importingImage = false;
  bool _cameraInitialized = false;
  Size _viewportSize = const Size(820, 1160);
  double get _zoom => _transformationController.value.entry(0, 0);
  Offset _toScreen(Offset point) =>
      MatrixUtils.transformPoint(_transformationController.value, point);
  Offset get _visibleCenter =>
      _toScene(Offset(_viewportSize.width / 2, _viewportSize.height / 2));
  Rect get _visibleRect => Rect.fromPoints(
    _toScene(Offset.zero),
    _toScene(Offset(_viewportSize.width, _viewportSize.height)),
  );

  void _cameraChanged() {
    if (mounted) setState(() {});
  }

  void _fitView({bool origin = false}) {
    final bounds = _isFixedPage
        ? const Rect.fromLTWH(0, 0, 820, 1160)
        : origin
        ? (Offset.zero & _viewportSize)
        : _contentBounds;
    final scale = min(
      (_viewportSize.width - 40) / bounds.width,
      (_viewportSize.height - 40) / bounds.height,
    ).clamp(0.1, 1.0);
    final offset =
        Offset(_viewportSize.width / 2, _viewportSize.height / 2) -
        bounds.center * scale;
    _transformationController.value = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(0, 3, offset.dx)
      ..setEntry(1, 3, offset.dy);
  }

  Rect get _contentBounds => CanvasContentBounds.compute(
    strokes: _strokes,
    images: _images,
    stickers: _stickers,
    text: _textAnnotations,
  );

  void _setPageMode(bool fixed) {
    setState(() => _isFixedPage = fixed);
    _fitView();
    _autoSave();
  }

  // Estado de la Regla Virtual
  Offset _rulerPosition = const Offset(140, 260);
  double _rulerAngle = 0.0;
  final double _rulerLength = 420.0;
  bool _isDraggingRuler = false;
  Offset? _rulerDragStart;

  // Estado de Selección por Lazo
  List<Offset>? _lassoPolygon;
  LassoSelection _activeSelection = const LassoSelection(selectedIds: {});
  Rect? _selectionBoundingBox;
  bool _isDraggingSelection = false;
  Offset? _selectionDragStart;

  // Archivo local de almacenamiento de trazos
  File? _storageFile;
  bool _isLoading = true;
  String? _loadError;
  bool _saveFailed = false;
  int? _drawingPointer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _transformationController.addListener(_cameraChanged);
    _activeTemplate = widget.page.templateId;
    _isFixedPage = widget.page.paperSize == 'A4';
    _paletteManager.initialize(baseDirectory: widget.baseDirectory).catchError((
      Object error,
    ) {
      debugPrint('No se pudieron cargar las paletas: $error');
    });
    _fontManager.initialize(baseDirectory: widget.baseDirectory);
    _stickerManager.initialize(baseDirectory: widget.baseDirectory);
    _attachmentManager.init(baseDirectory: widget.baseDirectory);

    if (widget.initialStrokes != null) {
      _strokes.addAll(widget.initialStrokes!);
      if (widget.initialTextAnnotations != null) {
        _textAnnotations.addAll(widget.initialTextAnnotations!);
      }
      if (widget.initialStickers != null) {
        _stickers.addAll(widget.initialStickers!);
      }
      _isLoading = false;
      _lastSnapshot = _snapshot();
    } else {
      _initStorageAndLoad();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _transformationController.removeListener(_cameraChanged);
    _transformationController.dispose();
    _recognitionService.dispose();
    super.dispose();
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await _autoSave();
    await AtomicJsonStore.flush();
    return _saveFailed ? AppExitResponse.cancel : AppExitResponse.exit;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _autoSave();
  }

  Future<void> _initStorageAndLoad() async {
    try {
      final appDir =
          widget.baseDirectory ?? await getApplicationDocumentsDirectory();
      final strokesDir = Directory('${appDir.path}/InkFlowData/strokes');
      if (!await strokesDir.exists()) {
        await strokesDir.create(recursive: true);
      }
      _storageFile = File('${strokesDir.path}/${widget.page.id}.json');

      final data = await AtomicJsonStore.read(_storageFile!);
      if (data != null) {
        if (mounted) {
          _isFixedPage = data['isFixedPage'] as bool? ?? _isFixedPage;
          final camera = data['camera'];
          if (camera is Map) {
            final x = (camera['x'] as num?)?.toDouble();
            final y = (camera['y'] as num?)?.toDouble();
            final zoom = (camera['zoom'] as num?)?.toDouble();
            if (x != null &&
                y != null &&
                zoom != null &&
                x.isFinite &&
                y.isFinite &&
                zoom.isFinite &&
                zoom >= 0.1 &&
                zoom <= 5) {
              _transformationController.value = Matrix4.identity()
                ..setEntry(0, 0, zoom)
                ..setEntry(1, 1, zoom)
                ..setEntry(0, 3, x)
                ..setEntry(1, 3, y);
              _cameraInitialized = true;
            }
          }
          _activeTemplate = data['templateId'] as String? ?? _activeTemplate;
          final strokesList = (data['strokes'] as List)
              .map((s) => Stroke.fromJson(s as Map<String, dynamic>))
              .toList();
          final textList =
              (data['textAnnotations'] as List?)
                  ?.map(
                    (t) => TextAnnotation.fromJson(t as Map<String, dynamic>),
                  )
                  .toList() ??
              [];
          final stickersList =
              (data['stickers'] as List?)
                  ?.map(
                    (s) => PlacedSticker.fromJson(s as Map<String, dynamic>),
                  )
                  .toList() ??
              [];
          final imagesList =
              (data['images'] as List?)
                  ?.map((i) => CanvasImage.fromJson(i as Map<String, dynamic>))
                  .toList() ??
              [];

          setState(() {
            _strokes.addAll(strokesList);
            _textAnnotations.addAll(textList);
            _stickers.addAll(stickersList);
            _images.addAll(imagesList);
          });
        }
      }
    } catch (e) {
      debugPrint('Error al cargar datos del lienzo: $e');
      _loadError =
          'No se pudo recuperar esta página. Se conserva el archivo original: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _lastSnapshot = _snapshot();
        });
      }
    }
  }

  Future<void> _autoSave({bool recordHistory = true}) async {
    final current = _snapshot();
    if (recordHistory &&
        _lastSnapshot != null &&
        !current.sameAs(_lastSnapshot!)) {
      _undoHistory.add(_lastSnapshot!);
      _redoHistory.clear();
      _lastSnapshot = current;
    }
    if (_storageFile == null || _loadError != null) return;
    try {
      final data = {
        'version': 5,
        'camera': {
          'x': _transformationController.value.entry(0, 3),
          'y': _transformationController.value.entry(1, 3),
          'zoom': _zoom,
        },
        'pageId': widget.page.id,
        'isFixedPage': _isFixedPage,
        'templateId': _activeTemplate,
        'strokes': _strokes.map((s) => s.toJson()).toList(),
        'textAnnotations': _textAnnotations.map((t) => t.toJson()).toList(),
        'stickers': _stickers.map((s) => s.toJson()).toList(),
        'images': _images.map((i) => i.toJson()).toList(),
      };
      await AtomicJsonStore.write(_storageFile!, data);
      if (widget.baseDirectory == null && mounted) {
        await recordPageEdit(ref, widget.page.id);
      }
      _saveFailed = false;
    } catch (e) {
      _saveFailed = true;
      debugPrint('Error al autoguardar lienzo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo guardar. Revisa el espacio disponible antes de salir.',
            ),
          ),
        );
      }
    }
  }

  _CanvasSnapshot _snapshot() => _CanvasSnapshot(
    List.of(_strokes),
    List.of(_textAnnotations),
    List.of(_stickers),
    List.of(_images),
    _activeTemplate,
    _isFixedPage,
  );

  void _restoreSnapshot(_CanvasSnapshot snapshot) {
    _strokes
      ..clear()
      ..addAll(snapshot.strokes);
    _textAnnotations
      ..clear()
      ..addAll(snapshot.text);
    _stickers
      ..clear()
      ..addAll(snapshot.stickers);
    _images
      ..clear()
      ..addAll(snapshot.images);
    _activeTemplate = snapshot.template;
    _isFixedPage = snapshot.fixed;
    _selectedImageId = null;
    _selectedStickerId = null;
    _clearSelection();
  }

  void _undo() {
    if (_undoHistory.isEmpty) return;
    setState(() {
      _redoHistory.add(_snapshot());
      _restoreSnapshot(_undoHistory.removeLast());
      _lastSnapshot = _snapshot();
    });
    _autoSave(recordHistory: false);
  }

  void _redo() {
    if (_redoHistory.isEmpty) return;
    setState(() {
      _undoHistory.add(_snapshot());
      _restoreSnapshot(_redoHistory.removeLast());
      _lastSnapshot = _snapshot();
    });
    _autoSave(recordHistory: false);
  }

  void _clearSelection() {
    _activeSelection = const LassoSelection(selectedIds: {});
    _selectionBoundingBox = null;
    _lassoPolygon = null;
  }

  void _clearCanvas() {
    if (_strokes.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar Lienzo'),
        content: const Text('¿Deseas borrar todos los trazos de esta página?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _strokes.clear();
                _clearSelection();
              });
              Navigator.pop(context);
              _autoSave();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Borrar Todo'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CONVERSIÓN DE COORDENADAS PANTALLA <-> ESCENA
  // ==========================================

  Offset _toScene(Offset screenOffset) {
    return _transformationController.toScene(screenOffset);
  }

  // ==========================================
  // GESTIÓN DE EVENTOS DE STYLUS / S PEN / PUNTERO
  // ==========================================

  void _onPointerDown(PointerDownEvent event) {
    final isStylus =
        event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus;

    // Rechazo de palma estricto: Si está activo y el evento es touch con dedo, ignorar para dibujo
    if (_strictPalmRejection &&
        !isStylus &&
        event.kind != PointerDeviceKind.mouse) {
      return;
    }
    if (_drawingPointer != null || _loadError != null) return;
    if (_isFixedPage &&
        !(const Rect.fromLTWH(
          0,
          0,
          820,
          1160,
        )).contains(_toScene(event.localPosition))) {
      return;
    }
    _drawingPointer = event.pointer;

    final scenePoint = _toScene(event.localPosition);
    if (_activeTool == DrawingToolType.lasso &&
        (_images.any((image) => image.containsPoint(scenePoint)) ||
            _stickers.any((sticker) => sticker.bounds.contains(scenePoint)))) {
      return;
    }

    // Si la herramienta Gotero está activa, tomar color bajo el puntero
    if (_isEyedropperActive) {
      _sampleColorAtPoint(scenePoint);
      return;
    }

    final bool sPenButtonPressed = (event.buttons & kSecondaryMouseButton) != 0;
    final currentTool = sPenButtonPressed
        ? DrawingToolType.eraser
        : _activeTool;

    // 1. Si hay una selección de lazo activa y se presiona dentro de su caja delimitadora:
    if (_activeSelection.isNotEmpty &&
        _selectionBoundingBox != null &&
        _selectionBoundingBox!.contains(scenePoint)) {
      setState(() {
        _isDraggingSelection = true;
        _selectionDragStart = scenePoint;
      });
      return;
    } else if (_activeSelection.isNotEmpty &&
        !_selectionBoundingBox!.contains(scenePoint)) {
      // Clic fuera deselecciona
      setState(() {
        _clearSelection();
      });
    }

    // 2. Si la regla virtual está activa y se presiona cerca de ella:
    if (_showRuler && _isNearRuler(scenePoint)) {
      setState(() {
        _isDraggingRuler = true;
        _rulerDragStart = scenePoint;
      });
      return;
    }

    // 3. Borrador por trazo o borrador por píxel
    if (currentTool == DrawingToolType.eraser ||
        currentTool == DrawingToolType.pixelEraser) {
      _eraseAtPoint(
        scenePoint,
        isPixel: currentTool == DrawingToolType.pixelEraser,
      );
      return;
    }

    // 4. Herramienta de Lazo
    if (currentTool == DrawingToolType.lasso) {
      setState(() {
        _clearSelection();
        _lassoPolygon = [scenePoint];
      });
      return;
    }

    // 5. Herramientas de trazo (bolígrafo, pluma, lápiz, pincel, resaltador)
    final double rawPressure = event.pressure;
    final double pressure = (rawPressure > 0.0 && rawPressure <= 1.0)
        ? rawPressure
        : 0.5;
    final double tilt = event.tilt;

    Offset strokePoint = scenePoint;
    // Si la regla está activa y el trazo está cerca del borde guía, ajustar al borde (Snap)
    if (_showRuler) {
      strokePoint = _snapToRuler(strokePoint);
    }

    setState(() {
      _currentStroke = Stroke(
        id: _uuid.v4(),
        tool: currentTool,
        color: _activeColor,
        width: _activeWidth,
        points: [
          StrokePoint(
            x: strokePoint.dx,
            y: strokePoint.dy,
            pressure: pressure,
            tilt: tilt,
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ),
        ],
      );
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _drawingPointer) return;
    final isStylus =
        event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus;
    if (_strictPalmRejection &&
        !isStylus &&
        event.kind != PointerDeviceKind.mouse) {
      return;
    }

    final scenePoint = _toScene(event.localPosition);
    final bool sPenButtonPressed = (event.buttons & kSecondaryMouseButton) != 0;
    final currentTool = sPenButtonPressed
        ? DrawingToolType.eraser
        : _activeTool;

    // Arrastre de trazos seleccionados con lazo
    if (_isDraggingSelection && _selectionDragStart != null) {
      final delta = scenePoint - _selectionDragStart!;
      _selectionDragStart = scenePoint;
      setState(() {
        final updated = _activeSelection.applyTranslation(_strokes, delta);
        _strokes
          ..clear()
          ..addAll(updated);
        _selectionBoundingBox = _activeSelection.computeBoundingBox(_strokes);
      });
      return;
    }

    // Arrastre de la regla virtual
    if (_isDraggingRuler && _rulerDragStart != null) {
      final delta = scenePoint - _rulerDragStart!;
      _rulerDragStart = scenePoint;
      setState(() {
        _rulerPosition += delta;
      });
      return;
    }

    // Lazo en trazado
    if (_lassoPolygon != null) {
      setState(() {
        _lassoPolygon!.add(scenePoint);
      });
      return;
    }

    // Borrado continuo
    if (currentTool == DrawingToolType.eraser ||
        currentTool == DrawingToolType.pixelEraser) {
      _eraseAtPoint(
        scenePoint,
        isPixel: currentTool == DrawingToolType.pixelEraser,
      );
      return;
    }

    if (_currentStroke == null) return;

    final double rawPressure = event.pressure;
    final double pressure = (rawPressure > 0.0 && rawPressure <= 1.0)
        ? rawPressure
        : 0.5;
    final double tilt = event.tilt;

    Offset strokePoint = scenePoint;
    if (_showRuler) {
      strokePoint = _snapToRuler(strokePoint);
    }

    setState(() {
      _currentStroke!.points.add(
        StrokePoint(
          x: strokePoint.dx,
          y: strokePoint.dy,
          pressure: pressure,
          tilt: tilt,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _drawingPointer) return;
    setState(() => _drawingPointer = null);
    if (_isDraggingSelection) {
      setState(() => _isDraggingSelection = false);
      _autoSave();
      return;
    }

    if (_isDraggingRuler) {
      setState(() => _isDraggingRuler = false);
      return;
    }

    // Finalizar selección por lazo
    if (_lassoPolygon != null && _lassoPolygon!.length > 2) {
      final selection = LassoSelection.fromPolygon(_lassoPolygon!, _strokes);
      setState(() {
        _activeSelection = selection;
        _lassoPolygon = null;
        if (_activeSelection.isNotEmpty) {
          _selectionBoundingBox = _activeSelection.computeBoundingBox(_strokes);
        } else {
          _selectionBoundingBox = null;
        }
      });
      return;
    }

    if (_currentStroke != null) {
      Stroke finalStroke = _currentStroke!;

      // Autocorrección de formas geométricas
      if (_autoShapeCorrection &&
          finalStroke.tool != DrawingToolType.highlighter) {
        final recognized = ShapeRecognizer.recognize(finalStroke.points);
        if (recognized != null) {
          finalStroke = finalStroke.copyWith(
            points: recognized.correctedPoints,
            isGeometric: true,
            geometricShape: recognized.shapeType,
          );
        }
      }

      setState(() {
        _strokes.add(finalStroke);
        _currentStroke = null;
      });
      _autoSave();
    }
  }

  // ==========================================
  // LÓGICA DE BORRADO (TRAZO Y PÍXEL)
  // ==========================================

  void _eraseAtPoint(Offset point, {bool isPixel = false}) {
    final updated = _strokes
        .expand(
          (stroke) => StrokeEraser.erase(
            stroke,
            point,
            isPixel ? 14 : 26,
            split: isPixel,
          ),
        )
        .toList();
    if (listEquals(updated, _strokes)) return;
    setState(() {
      _strokes
        ..clear()
        ..addAll(updated);
    });
    _autoSave();
  }

  // ==========================================
  // LÓGICA DE REGLA VIRTUAL Y AJUSTE (SNAP)
  // ==========================================

  bool _isNearRuler(Offset point) {
    final dx = point.dx - _rulerPosition.dx;
    final dy = point.dy - _rulerPosition.dy;
    // Rotar al espacio local de la regla
    final localX = dx * cos(-_rulerAngle) - dy * sin(-_rulerAngle);
    final localY = dx * sin(-_rulerAngle) + dy * cos(-_rulerAngle);

    return localX >= -16 &&
        localX <= _rulerLength + 16 &&
        localY >= -32 &&
        localY <= 32;
  }

  Offset _snapToRuler(Offset point) {
    final dx = point.dx - _rulerPosition.dx;
    final dy = point.dy - _rulerPosition.dy;
    final localX = dx * cos(-_rulerAngle) - dy * sin(-_rulerAngle);
    final localY = dx * sin(-_rulerAngle) + dy * cos(-_rulerAngle);

    // Si está a menos de 28pt del borde guía superior (-32.0 en Y local)
    if (localX >= 0 &&
        localX <= _rulerLength &&
        (localY - (-32.0)).abs() < 28.0) {
      const snappedLocalY = -32.0;
      final snappedWorldX =
          _rulerPosition.dx +
          localX * cos(_rulerAngle) -
          snappedLocalY * sin(_rulerAngle);
      final snappedWorldY =
          _rulerPosition.dy +
          localX * sin(_rulerAngle) +
          snappedLocalY * cos(_rulerAngle);
      return Offset(snappedWorldX, snappedWorldY);
    }
    return point;
  }

  // ==========================================
  // OPERACIONES DE LAZO DE SELECCIÓN
  // ==========================================

  void _duplicateSelection() {
    if (_activeSelection.isEmpty) return;
    final (updatedStrokes, newSelection) = _activeSelection.duplicate(_strokes);
    setState(() {
      _strokes
        ..clear()
        ..addAll(updatedStrokes);
      _activeSelection = newSelection;
      _selectionBoundingBox = _activeSelection.computeBoundingBox(_strokes);
    });
    _autoSave();
  }

  void _recolorSelection(Color color) {
    if (_activeSelection.isEmpty) return;
    setState(() {
      final updated = _activeSelection.applyColor(_strokes, color);
      _strokes
        ..clear()
        ..addAll(updated);
    });
    _autoSave();
  }

  void _deleteSelection() {
    if (_activeSelection.isEmpty) return;
    setState(() {
      _strokes.removeWhere((s) => _activeSelection.selectedIds.contains(s.id));
      _clearSelection();
    });
    _autoSave();
  }

  // ==========================================
  // OPERACIONES DE PALETA, FUENTES, OCR Y STICKERS
  // ==========================================

  void _sampleColorAtPoint(Offset point) {
    Color? sampled;
    double minDistance = double.infinity;

    for (final s in _strokes.reversed) {
      for (final p in s.points) {
        final d = (Offset(p.x, p.y) - point).distance;
        if (d < minDistance && d <= 36.0) {
          minDistance = d;
          sampled = s.color;
        }
      }
    }

    setState(() {
      _isEyedropperActive = false;
      if (sampled != null) {
        _activeColor = sampled;
        _paletteManager.addRecentColor(sampled);
      }
    });

    if (sampled != null && mounted) {
      final hex =
          '#${sampled.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Color capturado con gotero: $hex'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<String?> _recognizeOrTranscribe(List<Stroke> strokes) async {
    if (_recognitionService.isSupported) {
      return _recognitionService.recognize(
        strokes,
        languageCode: _recognitionLanguage,
      );
    }
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transcribir selección'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Escribe el texto de los trazos seleccionados. La conversión automática necesita un motor local sin telemetría y todavía no está incluida.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Texto para la selección',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Usar texto'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    return result;
  }

  Future<void> _convertSelectionToText() async {
    final selectedStrokes = _activeSelection.getSelectedStrokes(_strokes);
    if (selectedStrokes.isEmpty) return;

    final recognizedText = await _recognizeOrTranscribe(selectedStrokes);

    if (!mounted) return;

    if (recognizedText == null || recognizedText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se introdujo texto para la selección'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.text_fields_rounded, color: InkColors.primary),
            SizedBox(width: 8),
            Text('Texto transcrito'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                recognizedText,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copiar'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: recognizedText));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Texto copiado al portapapeles')),
              );
            },
          ),
          FilledButton.icon(
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Insertar en Lienzo'),
            onPressed: () {
              Navigator.of(context).pop();
              _replaceSelectionWithText(
                recognizedText,
                selectedStrokes,
                isPrettyFont: false,
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _convertSelectionToPrettyFont() async {
    final selectedStrokes = _activeSelection.getSelectedStrokes(_strokes);
    if (selectedStrokes.isEmpty) return;

    final recognizedText = await _recognizeOrTranscribe(selectedStrokes);

    if (!mounted) return;

    if (recognizedText == null || recognizedText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo transcribir la letra manuscrita'),
        ),
      );
      return;
    }

    _replaceSelectionWithText(
      recognizedText,
      selectedStrokes,
      isPrettyFont: true,
    );
  }

  void _replaceSelectionWithText(
    String text,
    List<Stroke> selectedStrokes, {
    bool isPrettyFont = true,
  }) {
    final bounds = _activeSelection.computeBoundingBox(_strokes);
    final primaryColor = selectedStrokes.isNotEmpty
        ? selectedStrokes.first.color
        : _activeColor;
    final fontSize = (bounds.height * 0.75).clamp(16.0, 72.0);

    final annotation = TextAnnotation(
      id: _uuid.v4(),
      text: text,
      position: bounds.topLeft + const Offset(4, 4),
      fontSize: fontSize,
      fontFamily: isPrettyFont ? _selectedHandwritingFont : 'PatrickHand',
      color: primaryColor,
    );

    setState(() {
      _strokes.removeWhere((s) => _activeSelection.selectedIds.contains(s.id));
      _textAnnotations.add(annotation);
      _clearSelection();
    });
    _autoSave();
  }

  Future<void> _saveSelectionAsSticker() async {
    final selectedStrokes = _activeSelection.getSelectedStrokes(_strokes);
    if (selectedStrokes.isEmpty) return;

    final bounds = _activeSelection.computeBoundingBox(_strokes);
    if (bounds.width <= 0 || bounds.height <= 0) return;

    try {
      final recorder = PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, bounds.width + 16, bounds.height + 16),
      );
      canvas.translate(-bounds.left + 8, -bounds.top + 8);

      for (final s in selectedStrokes) {
        final paint = Paint()
          ..color = s.color
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = s.width
          ..style = PaintingStyle.stroke;

        if (s.points.length > 1) {
          final path = Path()..moveTo(s.points.first.x, s.points.first.y);
          for (int i = 1; i < s.points.length; i++) {
            path.lineTo(s.points[i].x, s.points[i].y);
          }
          canvas.drawPath(path, paint);
        }
      }

      final picture = recorder.endRecording();
      final image = await picture.toImage(
        (bounds.width + 16).toInt().clamp(1, 2048),
        (bounds.height + 16).toInt().clamp(1, 2048),
      );
      final byteData = await image.toByteData(format: ImageByteFormat.png);

      if (byteData != null) {
        await _stickerManager.saveBytesAsSticker(
          byteData.buffer.asUint8List(),
          'recorte_${DateTime.now().millisecondsSinceEpoch}',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '¡Recorte guardado como Sticker en "Mis Stickers"!',
              ),
            ),
          );
          _clearSelection();
        }
      }
    } catch (e) {
      debugPrint('Error al guardar selección como sticker: $e');
    }
  }

  void _openStickerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StickerSheetModal(
        onStickerSelected: (sticker) {
          final sceneCenter = _visibleCenter;
          final placed = PlacedSticker(
            id: _uuid.v4(),
            assetPath: sticker.assetPath,
            filePath: sticker.filePath,
            isCustom: sticker.isCustom,
            position: sceneCenter - const Offset(50, 50),
            size: const Size(100, 100),
          );

          setState(() {
            _stickers.add(placed);
            _selectedStickerId = placed.id;
          });
          _autoSave();
        },
      ),
    );
  }

  void _openColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AdvancedColorPickerDialog(
        initialColor: _activeColor,
        onColorSelected: (newColor) {
          setState(() {
            _activeColor = newColor;
            if (_activeTool == DrawingToolType.eraser ||
                _activeTool == DrawingToolType.pixelEraser ||
                _activeTool == DrawingToolType.lasso) {
              _activeTool = DrawingToolType.pen;
            }
          });
        },
      ),
    );
  }

  void _addTypedTextAtCenter() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Insertar Texto en Lienzo'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Escribe tu nota aquí...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final text = textController.text.trim();
              if (text.isNotEmpty) {
                final sceneCenter = _visibleCenter;
                final annotation = TextAnnotation(
                  id: _uuid.v4(),
                  text: text,
                  position: sceneCenter - const Offset(60, 20),
                  fontSize: 26.0,
                  fontFamily: _selectedHandwritingFont,
                  color: _activeColor,
                );
                setState(() {
                  _textAnnotations.add(annotation);
                });
                _autoSave();
              }
              Navigator.pop(context);
            },
            child: const Text('Insertar'),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerWidget(PlacedSticker sticker) {
    final isSelected =
        _selectedStickerId == sticker.id &&
        _activeTool == DrawingToolType.lasso;
    final w = sticker.size.width * sticker.scale * _zoom;
    final h = sticker.size.height * sticker.scale * _zoom;

    return Positioned(
      left: _toScreen(sticker.position).dx,
      top: _toScreen(sticker.position).dy,
      width: w,
      height: h,
      child: IgnorePointer(
        ignoring: _activeTool != DrawingToolType.lasso,
        child: GestureDetector(
          dragStartBehavior: DragStartBehavior.down,
          onTap: () {
            setState(() {
              _selectedStickerId = isSelected ? null : sticker.id;
            });
          },
          onPanUpdate: (details) {
            setState(() {
              final idx = _stickers.indexWhere((s) => s.id == sticker.id);
              if (idx != -1) {
                _stickers[idx] = _stickers[idx].translate(
                  details.delta / _zoom,
                );
              }
            });
          },
          onPanEnd: (_) => _autoSave(),
          onPanCancel: () => _autoSave(),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: w,
                height: h,
                decoration: isSelected
                    ? BoxDecoration(
                        border: Border.all(color: InkColors.accent, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      )
                    : null,
                child: sticker.assetPath != null
                    ? SvgPicture.asset(sticker.assetPath!, fit: BoxFit.contain)
                    : (sticker.filePath != null &&
                          sticker.filePath!.endsWith('.svg'))
                    ? SvgPicture.file(
                        File(sticker.filePath!),
                        fit: BoxFit.contain,
                      )
                    : (sticker.filePath != null)
                    ? Image.file(File(sticker.filePath!), fit: BoxFit.contain)
                    : const Icon(Icons.broken_image),
              ),
              if (isSelected)
                Positioned(
                  right: 0,
                  top: 0,
                  child: GestureDetector(
                    dragStartBehavior: DragStartBehavior.down,
                    onTap: () {
                      setState(() {
                        _stickers.removeWhere((s) => s.id == sticker.id);
                        _selectedStickerId = null;
                      });
                      _autoSave();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _insertImage() async {
    if (_importingImage) return;
    setState(() => _importingImage = true);
    String? importedPath;
    bool inserted = false;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: false,
      );
      if (result == null || !mounted) return;
      final selected = result.files.single;
      if (selected.size > 40 * 1024 * 1024) {
        throw const FormatException('La imagen supera 40 MB.');
      }
      final bytes =
          selected.bytes ??
          (selected.path != null
              ? await File(selected.path!).readAsBytes()
              : null);
      if (bytes == null) {
        throw const FormatException(
          'No se pudo leer esta imagen. Prueba a guardarla primero en Descargas.',
        );
      }
      final imported = await _attachmentManager.importImageBytes(
        bytes,
        baseDirectory: widget.baseDirectory,
      );
      importedPath = imported.path;
      if (!mounted) return;
      final maxWidth = min(
        _isFixedPage ? 740.0 : double.infinity,
        min(480.0, _viewportSize.width * 0.65) / _zoom,
      );
      final maxHeight = min(
        _isFixedPage ? 1080.0 : double.infinity,
        min(600.0, _viewportSize.height * 0.65) / _zoom,
      );
      final factor = min(
        maxWidth / imported.width,
        maxHeight / imported.height,
      );
      final width = imported.width * factor;
      final height = imported.height * factor;
      var position = _visibleCenter - Offset(width / 2, height / 2);
      if (_isFixedPage) {
        position = Offset(
          position.dx.clamp(0, 820 - width),
          position.dy.clamp(0, 1160 - height),
        );
      }
      final image = CanvasImage(
        id: _uuid.v4(),
        filePath: imported.path,
        position: position,
        width: width,
        height: height,
      );
      setState(() {
        _images.add(image);
        _activeTool = DrawingToolType.lasso;
        _selectedImageId = image.id;
        _clearSelection();
      });
      inserted = true;
      await _autoSave();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Imagen añadida. Arrástrala para moverla y usa la esquina para cambiar su tamaño.',
            ),
          ),
        );
      }
    } catch (error) {
      debugPrint('Error al insertar imagen: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo añadir la imagen. Usa PNG, JPG o WebP. $error',
            ),
          ),
        );
      }
    } finally {
      if (!inserted && importedPath != null) await File(importedPath).delete();
      if (mounted) setState(() => _importingImage = false);
    }
  }

  Widget _buildImageWidget(CanvasImage image) {
    final isSelected =
        _selectedImageId == image.id && _activeTool == DrawingToolType.lasso;
    final w = image.width * image.scale * _zoom;
    final h = image.height * image.scale * _zoom;

    return Positioned(
      left: _toScreen(image.position).dx,
      top: _toScreen(image.position).dy,
      width: w,
      height: h,
      child: IgnorePointer(
        ignoring: _activeTool != DrawingToolType.lasso,
        child: GestureDetector(
          dragStartBehavior: DragStartBehavior.down,
          onTap: () {
            setState(() {
              _selectedImageId = isSelected ? null : image.id;
            });
          },
          onPanUpdate: (details) {
            setState(() {
              final idx = _images.indexWhere((i) => i.id == image.id);
              if (idx != -1) {
                _images[idx] = _images[idx].translate(details.delta / _zoom);
              }
            });
          },
          onPanEnd: (_) => _autoSave(),
          onPanCancel: () => _autoSave(),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: w,
                height: h,
                decoration: isSelected
                    ? BoxDecoration(
                        border: Border.all(color: InkColors.accent, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      )
                    : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(
                    File(image.filePath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
              if (isSelected) ...[
                // Botón de eliminar
                Positioned(
                  right: 0,
                  top: 0,
                  child: GestureDetector(
                    dragStartBehavior: DragStartBehavior.down,
                    onTap: () {
                      setState(() {
                        _images.removeWhere((i) => i.id == image.id);
                        _selectedImageId = null;
                      });
                      _autoSave();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Tirador de escalado en esquina inferior derecha
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    dragStartBehavior: DragStartBehavior.down,
                    onPanUpdate: (details) {
                      final factor = max(
                        0.1,
                        1 + (details.delta.dx + details.delta.dy) / (w + h),
                      );
                      setState(() {
                        final idx = _images.indexWhere((i) => i.id == image.id);
                        if (idx != -1) {
                          _images[idx] = _images[idx].scaleBy(factor);
                        }
                      });
                    },
                    onPanEnd: (_) => _autoSave(),
                    onPanCancel: () => _autoSave(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: InkColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.aspect_ratio_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openExportDialog() {
    showDialog(
      context: context,
      builder: (context) => ExportDialog(
        pageTitle: widget.page.title,
        canvasBounds: _isFixedPage
            ? const Rect.fromLTWH(0, 0, 820, 1160)
            : _contentBounds,
        paginateCanvas: !_isFixedPage,
        strokes: _strokes,
        textAnnotations: _textAnnotations,
        stickers: _stickers,
        images: _images,
        templateId: _activeTemplate,
        paperColor: Theme.of(context).brightness == Brightness.dark
            ? InkColors.paperDark
            : InkColors.paperWhite,
      ),
    );
  }

  // ==========================================
  // CONSTRUCCIÓN DE INTERFAZ DE USUARIO
  // ==========================================

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
      const SingleActivator(LogicalKeyboardKey.keyY, control: true): _redo,
      const SingleActivator(
        LogicalKeyboardKey.keyZ,
        control: true,
        shift: true,
      ): _redo,
      const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
        _autoSave();
      },
    },
    child: Focus(autofocus: true, child: _buildCanvas(context)),
  );

  Widget _buildCanvas(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.page.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo_rounded),
            tooltip: 'Deshacer (Ctrl+Z)',
            onPressed: _undoHistory.isNotEmpty ? _undo : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo_rounded),
            tooltip: 'Rehacer (Ctrl+Y)',
            onPressed: _redoHistory.isNotEmpty ? _redo : null,
          ),
          IconButton(
            icon: Icon(
              Icons.straighten_rounded,
              color: _showRuler ? InkColors.primary : null,
            ),
            tooltip: 'Regla Virtual',
            onPressed: () => setState(() => _showRuler = !_showRuler),
          ),
          if (_showRuler)
            IconButton(
              icon: const Icon(Icons.rotate_right_rounded),
              tooltip: 'Rotar Regla (+15°)',
              onPressed: () {
                setState(() {
                  _rulerAngle = (_rulerAngle + pi / 12) % (2 * pi);
                });
              },
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.dashboard_customize_outlined),
            tooltip: 'Plantilla de Papel',
            onSelected: (template) {
              setState(() => _activeTemplate = template);
              _autoSave();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'ruled',
                child: Text('Renglones con margen'),
              ),
              PopupMenuItem(
                value: 'grid',
                child: Text('Cuadrícula de ingeniería'),
              ),
              PopupMenuItem(value: 'dotted', child: Text('Punteado')),
              PopupMenuItem(value: 'cornell', child: Text('Notas Cornell')),
              PopupMenuItem(value: 'blank', child: Text('En Blanco')),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.font_download_rounded),
            tooltip: 'Tipografía Manuscrita ("Fuente Bonita")',
            onSelected: (font) {
              setState(() => _selectedHandwritingFont = font);
            },
            itemBuilder: (context) => _fontManager.availableFonts.map((f) {
              return PopupMenuItem(
                value: f.name,
                child: Row(
                  children: [
                    if (_selectedHandwritingFont == f.name)
                      const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: InkColors.primary,
                      )
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Text(f.displayName, style: TextStyle(fontFamily: f.name)),
                  ],
                ),
              );
            }).toList(),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Exportar Nota',
            onPressed: _openExportDialog,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Ajustes del Lienzo',
            onSelected: (option) {
              if (option == 'palm') {
                setState(() => _strictPalmRejection = !_strictPalmRejection);
              } else if (option == 'shape') {
                setState(() => _autoShapeCorrection = !_autoShapeCorrection);
              } else if (option == 'page_mode') {
                _setPageMode(!_isFixedPage);
              } else if (option == 'clear') {
                _clearCanvas();
              }
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: 'palm',
                checked: _strictPalmRejection,
                child: const Text('Rechazo estricto de palma (Solo S Pen)'),
              ),
              CheckedPopupMenuItem(
                value: 'shape',
                checked: _autoShapeCorrection,
                child: const Text('Autocorrección de formas geométricas'),
              ),
              CheckedPopupMenuItem(
                value: 'page_mode',
                checked: _isFixedPage,
                child: const Text('Modo Hoja Fija (A4)'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_outlined, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'Limpiar lienzo completo',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Área interactiva con zoom y desplazamiento
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SelectableText(_loadError!),
                  ),
                )
              : Positioned.fill(
                  top: 64,
                  bottom: 104,
                  child: _buildCanvasViewport(isDark),
                ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      icon: Icon(
                        _isFixedPage
                            ? Icons.description_outlined
                            : Icons.all_inclusive,
                      ),
                      label: Text(
                        _isFixedPage ? 'Hoja A4' : 'Lienzo infinito',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () => _setPageMode(!_isFixedPage),
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Añadir imagen',
                  onPressed: _importingImage ? null : _insertImage,
                  icon: _importingImage
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  tooltip: 'Ver todas las anotaciones',
                  onPressed: () {
                    _fitView();
                    _autoSave(recordHistory: false);
                  },
                  icon: const Icon(Icons.fit_screen),
                ),
                IconButton.filledTonal(
                  tooltip: 'Volver al inicio',
                  onPressed: () {
                    _fitView(origin: true);
                    _autoSave(recordHistory: false);
                  },
                  icon: const Icon(Icons.home_outlined),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 108,
            left: 16,
            right: 16,
            child: IgnorePointer(
              child: Text(
                '${(_zoom * 100).round()}% · S Pen para escribir · Dedos para mover y ampliar',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          ),

          // Barra contextual flotante cuando hay trazos seleccionados con lazo
          if (_activeSelection.isNotEmpty && _selectionBoundingBox != null)
            _buildLassoActionToolbar(isDark),

          // Barra flotante inferior de herramientas para stylus
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Center(child: _buildFloatingToolbar(isDark)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasViewport(bool isDark) => LayoutBuilder(
    builder: (context, constraints) {
      _viewportSize = constraints.biggest;
      if (!_cameraInitialized) {
        _cameraInitialized = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            if (_isFixedPage) _fitView();
          }
        });
      }
      final transform = _transformationController.value;
      final visible = _visibleRect;
      return InfiniteCanvasViewport(
        controller: _transformationController,
        navigationEnabled: _drawingPointer == null,
        onNavigationEnd: () => _autoSave(recordHistory: false),
        child: Listener(
          key: const ValueKey('ink-canvas-input'),
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: (event) {
            if (event.pointer == _drawingPointer) {
              setState(() {
                _drawingPointer = null;
                _currentStroke = null;
                _lassoPolygon = null;
                _isDraggingSelection = false;
                _isDraggingRuler = false;
              });
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: isDark
                      ? const Color(0xFF141820)
                      : const Color(0xFFE8ECF1),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: CanvasPainter(
                      strokes: const [],
                      templateId: _activeTemplate,
                      isFixedPage: _isFixedPage,
                      viewTransform: transform,
                      visibleRect: visible,
                      paperColor: isDark
                          ? InkColors.paperDark
                          : InkColors.paperWhite,
                      gridColor: isDark
                          ? InkColors.gridDark
                          : InkColors.gridLight,
                    ),
                  ),
                ),
              ),
              ..._images.map(_buildImageWidget),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: CanvasPainter(
                      strokes: _strokes,
                      activeStroke: _currentStroke,
                      textAnnotations: _textAnnotations,
                      templateId: 'blank',
                      paperColor: Colors.transparent,
                      viewTransform: transform,
                      visibleRect: visible,
                      lassoPolygon: _lassoPolygon,
                      selectedStrokeIds: _activeSelection.selectedIds,
                      selectionBoundingBox: _selectionBoundingBox,
                      showRuler: _showRuler,
                      rulerPosition: _rulerPosition,
                      rulerAngle: _rulerAngle,
                      rulerLength: _rulerLength,
                    ),
                  ),
                ),
              ),
              ..._stickers.map(_buildStickerWidget),
            ],
          ),
        ),
      );
    },
  );

  Widget _buildLassoActionToolbar(bool isDark) {
    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? InkColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF0284C7), width: 1.5),
              boxShadow: InkSpacing.elevationFloatingToolbar,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Selección',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(width: 10),
                // Selector de color para recolorear
                ...[
                  const Color(0xFF1E293B),
                  const Color(0xFF2563EB),
                  const Color(0xFFDC2626),
                  const Color(0xFF16A34A),
                ].map(
                  (c) => GestureDetector(
                    onTap: () => _recolorSelection(c),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  tooltip: 'Duplicar Selección',
                  onPressed: _duplicateSelection,
                ),
                IconButton(
                  icon: const Icon(Icons.text_fields_rounded, size: 20),
                  tooltip: 'Transcribir selección',
                  onPressed: _convertSelectionToText,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.auto_fix_high_rounded,
                    size: 20,
                    color: Color(0xFFD97706),
                  ),
                  tooltip: 'Fuente Bonita (Caligráfica)',
                  onPressed: _convertSelectionToPrettyFont,
                ),
                IconButton(
                  icon: const Icon(Icons.loyalty_rounded, size: 20),
                  tooltip: 'Guardar como Sticker',
                  onPressed: _saveSelectionAsSticker,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: Colors.red,
                  ),
                  tooltip: 'Eliminar Selección',
                  onPressed: _deleteSelection,
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Deseleccionar',
                  onPressed: () => setState(() => _clearSelection()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingToolbar(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? InkColors.surfaceDark : Colors.white,
          borderRadius: InkSpacing.roundedFull,
          border: Border.all(
            color: isDark ? InkColors.borderDark : InkColors.borderLight,
          ),
          boxShadow: InkSpacing.elevationFloatingToolbar,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bolígrafo
            _buildToolButton(
              tool: DrawingToolType.pen,
              icon: Icons.edit_rounded,
              tooltip: 'Bolígrafo',
            ),
            // Pluma Caligráfica
            _buildToolButton(
              tool: DrawingToolType.fountainPen,
              icon: Icons.history_edu_rounded,
              tooltip: 'Pluma Caligráfica',
            ),
            // Lápiz
            _buildToolButton(
              tool: DrawingToolType.pencil,
              icon: Icons.create_rounded,
              tooltip: 'Lápiz Grafito',
            ),
            // Pincel
            _buildToolButton(
              tool: DrawingToolType.brush,
              icon: Icons.brush_rounded,
              tooltip: 'Pincel Artístico',
            ),
            // Resaltador
            _buildToolButton(
              tool: DrawingToolType.highlighter,
              icon: Icons.border_color_rounded,
              tooltip: 'Resaltador',
            ),
            // Borrador por trazo
            _buildToolButton(
              tool: DrawingToolType.eraser,
              icon: Icons.cleaning_services_rounded,
              tooltip: 'Borrador de Trazo',
            ),
            // Borrador de píxeles
            _buildToolButton(
              tool: DrawingToolType.pixelEraser,
              icon: Icons.auto_fix_normal_rounded,
              tooltip: 'Borrador de Precisión',
            ),
            // Lazo de selección
            _buildToolButton(
              tool: DrawingToolType.lasso,
              icon: Icons.gesture_rounded,
              tooltip: 'Lazo de Selección',
            ),
            const SizedBox(width: 4),
            Container(
              height: 24,
              width: 1,
              color: Colors.grey.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 4),
            // Gotero (Eyedropper)
            IconButton(
              icon: Icon(
                Icons.colorize_rounded,
                size: 20,
                color: _isEyedropperActive ? InkColors.accent : null,
              ),
              tooltip: 'Gotero (Muestrear color del lienzo)',
              onPressed: () {
                setState(() => _isEyedropperActive = !_isEyedropperActive);
                if (_isEyedropperActive) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Modo Gotero activo: toca cualquier trazo para tomar su color',
                      ),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            // Paleta avanzada HSV / HEX
            IconButton(
              icon: const Icon(Icons.palette_rounded, size: 20),
              tooltip: 'Paleta Avanzada HSV / HEX',
              onPressed: _openColorPicker,
            ),
            // Paleta de colores rápidos
            ...InkColors.defaultInkPalette.take(4).map((color) {
              final isSelected =
                  _activeColor == color &&
                  _activeTool != DrawingToolType.eraser &&
                  _activeTool != DrawingToolType.pixelEraser &&
                  _activeTool != DrawingToolType.lasso;
              return IconButton(
                tooltip:
                    'Tinta #${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                isSelected: isSelected,
                onPressed: () {
                  setState(() {
                    _activeColor = color;
                    _paletteManager.addRecentColor(color);
                    _isEyedropperActive = false;
                    if (_activeTool == DrawingToolType.eraser ||
                        _activeTool == DrawingToolType.pixelEraser ||
                        _activeTool == DrawingToolType.lasso) {
                      _activeTool = DrawingToolType.pen;
                    }
                  });
                },
                icon: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? InkColors.primary : Colors.white,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(width: 4),
            Container(
              height: 24,
              width: 1,
              color: Colors.grey.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 4),
            // Stickers
            IconButton(
              icon: const Icon(Icons.interests_rounded, size: 20),
              tooltip: 'Biblioteca de Stickers',
              onPressed: _openStickerSheet,
            ),
            // Insertar Texto tipado
            IconButton(
              icon: const Icon(Icons.text_fields_rounded, size: 20),
              tooltip: 'Insertar Texto en Lienzo',
              onPressed: _addTypedTextAtCenter,
            ),
            // Insertar Imagen
            IconButton(
              icon: const Icon(Icons.image_outlined, size: 20),
              tooltip: 'Insertar Imagen en Lienzo',
              onPressed: _insertImage,
            ),
            // Grosor de trazo
            PopupMenuButton<double>(
              icon: const Icon(Icons.line_weight_rounded, size: 20),
              tooltip: 'Grosor de trazo',
              onSelected: (width) => setState(() => _activeWidth = width),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 1.5,
                  child: Text('Extra Fino (1.5 pt)'),
                ),
                const PopupMenuItem(value: 3.0, child: Text('Fino (3.0 pt)')),
                const PopupMenuItem(value: 5.0, child: Text('Medio (5.0 pt)')),
                const PopupMenuItem(value: 8.0, child: Text('Grueso (8.0 pt)')),
                const PopupMenuItem(
                  value: 14.0,
                  child: Text('Marcador (14.0 pt)'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required DrawingToolType tool,
    required IconData icon,
    required String tooltip,
  }) {
    final isSelected = _activeTool == tool;

    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      color: isSelected ? InkColors.primary : Colors.grey.shade600,
      style: isSelected
          ? IconButton.styleFrom(
              backgroundColor: InkColors.primary.withValues(alpha: 0.14),
            )
          : null,
      onPressed: () {
        setState(() {
          _activeTool = tool;
          if (tool != DrawingToolType.lasso) {
            _clearSelection();
          }
        });
      },
    );
  }
}

/// El historial comparte objetos inmutables; evita duplicar todos los puntos en JSON.
class _CanvasSnapshot {
  final List<Stroke> strokes;
  final List<TextAnnotation> text;
  final List<PlacedSticker> stickers;
  final List<CanvasImage> images;
  final String template;
  final bool fixed;
  _CanvasSnapshot(
    this.strokes,
    this.text,
    this.stickers,
    this.images,
    this.template,
    this.fixed,
  );
  bool sameAs(_CanvasSnapshot other) =>
      listEquals(strokes, other.strokes) &&
      listEquals(text, other.text) &&
      listEquals(stickers, other.stickers) &&
      listEquals(images, other.images) &&
      template == other.template &&
      fixed == other.fixed;
}
