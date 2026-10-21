import 'dart:ui' show AppExitResponse;
import 'dart:async';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/storage/atomic_json_store.dart';
import '../../../shared/providers/database_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../data/database/app_database.dart';
import '../../export/presentation/widgets/export_dialog.dart';

/// Pantalla del Editor de Bloques (Rich Text y Bloques) basada en AppFlowy Editor.
///
/// Soporta:
/// - Párrafos, Encabezados (H1, H2, H3, H4, H5, H6), Listas ordenadas y desordenadas.
/// - Listas de tareas (Checklists / To-do), Citas (Quotes), Divisores.
/// - Tablas integradas de AppFlowy con celdas editables.
/// - Menú slash ('/') para inserción rápida de bloques.
/// - Persistencia 100% offline en formato JSON estándar en el dispositivo.
/// - Autoguardado debounced y soporte deshacer/rehacer ilimitado.
/// - Modos adaptativos: Barra flotante en escritorio y barra táctil en tablet/móvil.
class EditorScreen extends ConsumerStatefulWidget {
  final Page page;
  final Directory? baseDirectory;
  final EditorState? initialEditorState;

  const EditorScreen({
    super.key,
    required this.page,
    this.baseDirectory,
    this.initialEditorState,
  });

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen>
    with WidgetsBindingObserver {
  EditorState? _editorState;
  EditorScrollController? _editorScrollController;
  StreamSubscription? _transactionSubscription;

  File? _storageFile;
  bool _isLoading = true;
  String? _loadError;
  int _revision = 0;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  DateTime? _lastSaved;
  Timer? _autoSaveDebounceTimer;
  Timer? _continuousSaveTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initStorageAndDocument();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _continuousSaveTimer?.cancel();
    _autoSaveDebounceTimer?.cancel();
    _transactionSubscription?.cancel();
    if (_hasUnsavedChanges && _editorState != null) {
      _saveDocumentSync();
    }
    _editorScrollController?.dispose();
    _editorState?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_hasUnsavedChanges) _saveDocument();
    }
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    _autoSaveDebounceTimer?.cancel();
    await _saveDocument();
    await AtomicJsonStore.flush();
    if (_hasUnsavedChanges) await _saveDocument();
    await AtomicJsonStore.flush();
    return _hasUnsavedChanges ? AppExitResponse.cancel : AppExitResponse.exit;
  }

  /// Inicializa la ruta de persistencia y carga o crea el documento AppFlowy.
  Future<void> _initStorageAndDocument() async {
    try {
      if (widget.initialEditorState != null) {
        final state = widget.initialEditorState!;
        _editorScrollController = EditorScrollController(
          editorState: state,
          shrinkWrap: false,
        );
        _transactionSubscription = state.transactionStream.listen((_) {
          if (mounted) {
            setState(() {
              _hasUnsavedChanges = true;
              _revision++;
            });
            _scheduleAutoSave();
          }
        });
        setState(() {
          _editorState = state;
          _isLoading = false;
        });
        return;
      }

      final appDir =
          widget.baseDirectory ?? await getApplicationDocumentsDirectory();
      final editorDir = Directory('${appDir.path}/InkFlowData/editor');
      if (!await editorDir.exists()) {
        await editorDir.create(recursive: true);
      }
      _storageFile = File('${editorDir.path}/${widget.page.id}.json');

      EditorState state;
      final stored = await AtomicJsonStore.read(_storageFile!);
      if (stored != null) {
        state = EditorState(document: Document.fromJson(stored));
      } else {
        state = EditorState.blank(withInitialText: true);
      }

      if (!mounted) {
        state.dispose();
        return;
      }
      _editorScrollController = EditorScrollController(
        editorState: state,
        shrinkWrap: false,
      );

      _transactionSubscription = state.transactionStream.listen((_) {
        if (mounted) {
          setState(() {
            _hasUnsavedChanges = true;
            _revision++;
          });
          _scheduleAutoSave();
        }
      });

      setState(() {
        _editorState = state;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error al inicializar editor: $e');
      if (mounted) {
        setState(() {
          _loadError =
              'No se pudo recuperar el documento. Se conserva el archivo original: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Programa el autoguardado tras 1.5 segundos de inactividad de escritura.
  void _scheduleAutoSave() {
    _continuousSaveTimer ??= Timer.periodic(const Duration(seconds: 5), (_) {
      if (_hasUnsavedChanges) _saveDocument();
    });
    _autoSaveDebounceTimer?.cancel();
    _autoSaveDebounceTimer = Timer(const Duration(milliseconds: 1500), () {
      _saveDocument();
    });
  }

  /// Guarda el documento en disco en formato JSON.
  Future<void> _saveDocument() async {
    if (_editorState == null || _storageFile == null) return;
    if (_isSaving || _loadError != null || !mounted) return;
    final savedRevision = _revision;

    setState(() => _isSaving = true);
    try {
      final jsonMap = _editorState!.document.toJson();
      await AtomicJsonStore.write(_storageFile!, jsonMap);
      if (widget.baseDirectory == null && mounted) {
        await recordPageEdit(ref, widget.page.id);
      }

      if (mounted) {
        setState(() {
          _isSaving = false;
          _hasUnsavedChanges = savedRevision != _revision;
          if (!_hasUnsavedChanges) {
            _continuousSaveTimer?.cancel();
            _continuousSaveTimer = null;
          }
          if (_hasUnsavedChanges) _scheduleAutoSave();
          _lastSaved = DateTime.now();
        });
      }
    } catch (e) {
      debugPrint('Error al guardar documento: $e');
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Guardado síncrono al desmontar el widget para no perder cambios.
  void _saveDocumentSync() {
    if (_editorState == null || _storageFile == null) return;
    try {
      final jsonMap = _editorState!.document.toJson();
      unawaited(
        AtomicJsonStore.write(_storageFile!, jsonMap).catchError((
          Object error,
        ) {
          debugPrint('Error al guardar al salir: $error');
        }),
      );
    } catch (e) {
      debugPrint('Error en guardado síncrono: $e');
    }
  }

  void _undo() {
    if (_editorState == null) return;
    _editorState!.undoManager.undo();
  }

  void _redo() {
    if (_editorState == null) return;
    _editorState!.undoManager.redo();
  }

  /// Construye el estilo del editor para modo escritorio (Windows)
  EditorStyle _buildDesktopEditorStyle(bool isDark) {
    final textColor = isDark
        ? InkColors.textPrimaryDark
        : InkColors.textPrimaryLight;

    return EditorStyle.desktop(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      cursorColor: InkColors.primary,
      cursorWidth: 2.0,
      selectionColor: InkColors.primary.withValues(alpha: 0.25),
      textStyleConfiguration: TextStyleConfiguration(
        text: InkTypography.bodyLarge.copyWith(color: textColor),
        bold: InkTypography.bodyLarge.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
        italic: InkTypography.bodyLarge.copyWith(
          color: textColor,
          fontStyle: FontStyle.italic,
        ),
        underline: InkTypography.bodyLarge.copyWith(
          color: textColor,
          decoration: TextDecoration.underline,
        ),
        strikethrough: InkTypography.bodyLarge.copyWith(
          color: textColor,
          decoration: TextDecoration.lineThrough,
        ),
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          color: isDark ? const Color(0xFFF472B6) : const Color(0xFFDB2777),
          backgroundColor: isDark
              ? const Color(0xFF1E293B)
              : const Color(0xFFF1F5F9),
        ),
      ),
    );
  }

  /// Construye el estilo del editor para tablet / móvil (Android con S Pen o táctil)
  EditorStyle _buildMobileEditorStyle(bool isDark) {
    final textColor = isDark
        ? InkColors.textPrimaryDark
        : InkColors.textPrimaryLight;

    return EditorStyle.mobile(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      cursorColor: InkColors.primary,
      dragHandleColor: InkColors.primary,
      cursorWidth: 2.0,
      selectionColor: InkColors.primary.withValues(alpha: 0.25),
      textStyleConfiguration: TextStyleConfiguration(
        text: InkTypography.bodyLarge.copyWith(color: textColor),
        bold: InkTypography.bodyLarge.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
        italic: InkTypography.bodyLarge.copyWith(
          color: textColor,
          fontStyle: FontStyle.italic,
        ),
        underline: InkTypography.bodyLarge.copyWith(
          color: textColor,
          decoration: TextDecoration.underline,
        ),
        strikethrough: InkTypography.bodyLarge.copyWith(
          color: textColor,
          decoration: TextDecoration.lineThrough,
        ),
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          color: isDark ? const Color(0xFFF472B6) : const Color(0xFFDB2777),
          backgroundColor: isDark
              ? const Color(0xFF1E293B)
              : const Color(0xFFF1F5F9),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(widget.page.title, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            if (_isSaving)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (_hasUnsavedChanges)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
              )
            else if (_lastSaved != null)
              Icon(
                Icons.check_circle_outline,
                size: 16,
                color: Colors.green.shade400,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo_rounded),
            tooltip: 'Deshacer (Ctrl+Z)',
            onPressed: _undo,
          ),
          IconButton(
            icon: const Icon(Icons.redo_rounded),
            tooltip: 'Rehacer (Ctrl+Y)',
            onPressed: _redo,
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Guardar Documento',
            onPressed: _saveDocument,
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Exportar Documento (Markdown, PDF, Respaldo)',
            onPressed: () {
              if (_editorState == null) return;
              showDialog(
                context: context,
                builder: (context) => ExportDialog(
                  pageTitle: widget.page.title,
                  editorJson: _editorState!.document.toJson(),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Opciones de Documento',
            onSelected: (action) {
              if (action == 'info') {
                _showDocumentInfo(context);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20),
                    SizedBox(width: 12),
                    Text('Información de la Nota'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SelectableText(_loadError!),
              ),
            )
          : _buildEditorBody(isDark),
    );
  }

  Widget _buildEditorBody(bool isDark) {
    if (_editorState == null || _editorScrollController == null) {
      return const SizedBox.shrink();
    }

    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    if (isDesktop) {
      return FloatingToolbar(
        items: [
          paragraphItem,
          ...headingItems,
          ...markdownFormatItems,
          quoteItem,
          bulletedListItem,
          numberedListItem,
          linkItem,
          buildTextColorItem(),
          buildHighlightColorItem(),
          ...textDirectionItems,
          ...alignmentItems,
        ],
        tooltipBuilder: (context, _, message, child) {
          return Tooltip(message: message, preferBelow: false, child: child);
        },
        editorState: _editorState!,
        textDirection: TextDirection.ltr,
        editorScrollController: _editorScrollController!,
        child: AppFlowyEditor(
          editorState: _editorState!,
          editorScrollController: _editorScrollController,
          editorStyle: _buildDesktopEditorStyle(isDark),
        ),
      );
    } else {
      // Tablet / Móvil (Android Galaxy Tab S10 Lite + S Pen o táctil)
      return MobileToolbarV2(
        toolbarHeight: 48.0,
        toolbarItems: [
          textDecorationMobileToolbarItemV2,
          buildTextAndBackgroundColorMobileToolbarItem(),
          blocksMobileToolbarItem,
          linkMobileToolbarItem,
          dividerMobileToolbarItem,
        ],
        editorState: _editorState!,
        child: MobileFloatingToolbar(
          editorState: _editorState!,
          editorScrollController: _editorScrollController!,
          floatingToolbarHeight: 36,
          toolbarBuilder: (context, anchor, closeToolbar) {
            return AdaptiveTextSelectionToolbar.editable(
              clipboardStatus: ClipboardStatus.pasteable,
              onCopy: () {
                copyCommand.execute(_editorState!);
                closeToolbar();
              },
              onCut: () => cutCommand.execute(_editorState!),
              onPaste: () => pasteCommand.execute(_editorState!),
              onSelectAll: () => selectAllCommand.execute(_editorState!),
              onLiveTextInput: null,
              onLookUp: null,
              onSearchWeb: null,
              onShare: null,
              anchors: TextSelectionToolbarAnchors(primaryAnchor: anchor),
            );
          },
          child: AppFlowyEditor(
            editorState: _editorState!,
            editorScrollController: _editorScrollController,
            editorStyle: _buildMobileEditorStyle(isDark),
          ),
        ),
      );
    }
  }

  void _showDocumentInfo(BuildContext context) {
    if (_editorState == null) return;
    final blockCount = _editorState!.document.root.children.length;
    final buffer = StringBuffer();
    for (final node in _editorState!.document.root.children) {
      final text = node.delta?.toPlainText();
      if (text != null && text.isNotEmpty) {
        buffer.writeln(text);
      }
    }
    final plainText = buffer.toString();
    final wordCount = plainText.trim().isEmpty
        ? 0
        : plainText.trim().split(RegExp(r'\s+')).length;
    final charCount = plainText.length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.article_outlined),
            SizedBox(width: 8),
            Text('Estadísticas'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('Palabras:', '$wordCount'),
            _buildStatRow('Caracteres:', '$charCount'),
            _buildStatRow('Bloques totales:', '$blockCount'),
            _buildStatRow('Tipo:', 'Documento enriquecido'),
            if (_lastSaved != null)
              _buildStatRow(
                'Último guardado:',
                '${_lastSaved!.hour.toString().padLeft(2, '0')}:${_lastSaved!.minute.toString().padLeft(2, '0')}:${_lastSaved!.second.toString().padLeft(2, '0')}',
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
