import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/colors.dart';
import '../../../data/database/app_database.dart';
import '../../../shared/providers/database_provider.dart';
import '../../canvas/presentation/canvas_screen.dart';
import '../../editor/presentation/editor_screen.dart';
import '../../pdf/presentation/pdf_annotation_screen.dart';
import '../../library/presentation/page_library_view.dart';

/// Proveedor para observar las secciones de este cuaderno
final sectionsForNotebookProvider =
    StreamProvider.family<List<Section>, String>((ref, notebookId) {
      final db = ref.watch(databaseProvider);
      return db.watchSectionsForNotebook(notebookId);
    });

/// Proveedor para observar las páginas de la sección activa
final pagesForSectionProvider = StreamProvider.family<List<Page>, String>((
  ref,
  sectionId,
) {
  final db = ref.watch(databaseProvider);
  return db.watchActivePagesForSection(sectionId);
});

/// Pantalla del Cuaderno: Organiza secciones y páginas.
class NotebookScreen extends ConsumerStatefulWidget {
  final String notebookId;

  const NotebookScreen({super.key, required this.notebookId});

  @override
  ConsumerState<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends ConsumerState<NotebookScreen> {
  static const _uuid = Uuid();
  String? _activeSectionId;

  void _openPage(Page page) {
    ref.read(selectedPageIdProvider.notifier).state = page.id;

    if (page.pageType == 'pdf') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PdfAnnotationScreen(page: page),
        ),
      );
    } else if (page.pageType == 'text') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => EditorScreen(page: page)));
    } else if (page.pageType == 'mixed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Modo mixto: Abriendo en editor de bloques'),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => EditorScreen(page: page)));
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => CanvasScreen(page: page)));
    }
  }

  Future<void> _createPage(String sectionId) async {
    final titleController = TextEditingController(text: 'Nueva Página');
    String selectedType = 'canvas';
    String selectedTemplate = 'ruled';

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return AlertDialog(
            title: const Text('Crear Nueva Página'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Título de la Página',
                        prefixIcon: Icon(Icons.title_rounded),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Tipo de Página',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                setDialogState(() => selectedType = 'canvas'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: selectedType == 'canvas'
                                    ? InkColors.primary.withValues(alpha: 0.15)
                                    : (isDark
                                          ? InkColors.cardDark
                                          : Colors.grey.shade100),
                                border: Border.all(
                                  color: selectedType == 'canvas'
                                      ? InkColors.primary
                                      : Colors.grey.withValues(alpha: 0.3),
                                  width: selectedType == 'canvas' ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.gesture_rounded,
                                    size: 28,
                                    color: selectedType == 'canvas'
                                        ? InkColors.primary
                                        : Colors.grey,
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Lienzo (Stylus)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Dibujo y S Pen',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                setDialogState(() => selectedType = 'text'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: selectedType == 'text'
                                    ? InkColors.primary.withValues(alpha: 0.15)
                                    : (isDark
                                          ? InkColors.cardDark
                                          : Colors.grey.shade100),
                                border: Border.all(
                                  color: selectedType == 'text'
                                      ? InkColors.primary
                                      : Colors.grey.withValues(alpha: 0.3),
                                  width: selectedType == 'text' ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.article_rounded,
                                    size: 28,
                                    color: selectedType == 'text'
                                        ? InkColors.primary
                                        : Colors.grey,
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Documento',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Texto y bloques',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                setDialogState(() => selectedType = 'pdf'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: selectedType == 'pdf'
                                    ? Colors.red.withValues(alpha: 0.15)
                                    : (isDark
                                          ? InkColors.cardDark
                                          : Colors.grey.shade100),
                                border: Border.all(
                                  color: selectedType == 'pdf'
                                      ? Colors.red
                                      : Colors.grey.withValues(alpha: 0.3),
                                  width: selectedType == 'pdf' ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.picture_as_pdf_rounded,
                                    size: 28,
                                    color: selectedType == 'pdf'
                                        ? Colors.red
                                        : Colors.grey,
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'PDF',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Anotar archivo',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (selectedType == 'canvas') ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Plantilla de Papel',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedTemplate,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.dashboard_customize_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'ruled',
                            child: Text('Rayado (Renglones)'),
                          ),
                          DropdownMenuItem(
                            value: 'grid',
                            child: Text('Cuadriculado'),
                          ),
                          DropdownMenuItem(
                            value: 'dotted',
                            child: Text('Punteado'),
                          ),
                          DropdownMenuItem(
                            value: 'blank',
                            child: Text('En Blanco'),
                          ),
                          DropdownMenuItem(
                            value: 'cornell',
                            child: Text('Notas Cornell'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedTemplate = val);
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('Crear Página'),
              ),
            ],
          );
        },
      ),
    );

    if (result != true) return;

    final db = ref.read(databaseProvider);
    final pageId = _uuid.v4();
    final now = DateTime.now();
    final title = titleController.text.trim().isEmpty
        ? 'Página sin título'
        : titleController.text.trim();

    await db.insertPage(
      PagesCompanion(
        paperSize: drift.Value(selectedType == 'canvas' ? 'Infinite' : 'A4'),
        id: drift.Value(pageId),
        sectionId: drift.Value(sectionId),
        title: drift.Value(title),
        pageType: drift.Value(selectedType),
        templateId: drift.Value(selectedTemplate),
        paperColor: const drift.Value('#FFFFFF'),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );

    final newPage = await db.getPageById(pageId);
    if (newPage != null && mounted) {
      _openPage(newPage);
    }
  }

  Future<void> _createNewSection() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva Sección'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre de la Sección',
            hintText: 'Ej. Primer Parcial, Laboratorio',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final db = ref.read(databaseProvider);
      final sectionId = _uuid.v4();
      final now = DateTime.now();

      await db.insertSection(
        SectionsCompanion(
          id: drift.Value(sectionId),
          notebookId: drift.Value(widget.notebookId),
          title: drift.Value(result),
          sortOrder: const drift.Value(0),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );

      setState(() => _activeSectionId = sectionId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sectionsAsync = ref.watch(
      sectionsForNotebookProvider(widget.notebookId),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuaderno'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined),
            tooltip: 'Nueva Sección',
            onPressed: _createNewSection,
          ),
        ],
      ),
      body: sectionsAsync.when(
        data: (sections) {
          if (sections.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.folder_open_rounded,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  const Text('No hay secciones en este cuaderno'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _createNewSection,
                    child: const Text('Crear Primera Sección'),
                  ),
                ],
              ),
            );
          }

          // Si no hay sección seleccionada, seleccionar la primera por defecto
          final effectiveSectionId = _activeSectionId ?? sections.first.id;

          return Column(
            children: [
              // Pestañas horizontales de secciones (estilo separadores de cuaderno)
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: isDark
                      ? InkColors.surfaceDark
                      : InkColors.surfaceVariantLight,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? InkColors.borderDark
                          : InkColors.borderLight,
                    ),
                  ),
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: sections.length + 1,
                  itemBuilder: (context, index) {
                    if (index == sections.length) {
                      return IconButton(
                        icon: const Icon(Icons.add, size: 20),
                        tooltip: 'Agregar sección',
                        onPressed: _createNewSection,
                      );
                    }

                    final section = sections[index];
                    final isSelected = section.id == effectiveSectionId;

                    return Padding(
                      padding: const EdgeInsets.only(
                        right: 8,
                        top: 4,
                        bottom: 4,
                      ),
                      child: ChoiceChip(
                        label: Text(section.title),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() => _activeSectionId = section.id);
                        },
                      ),
                    );
                  },
                ),
              ),
              // Grid de páginas de la sección activa
              Expanded(child: _buildPagesGrid(effectiveSectionId, isDark)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final sections = sectionsAsync.value;
          if (sections != null && sections.isNotEmpty) {
            final targetSection = _activeSectionId ?? sections.first.id;
            _createPage(targetSection);
          }
        },
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text('Nueva Página'),
      ),
    );
  }

  Widget _buildPagesGrid(String sectionId, bool isDark) => PageLibraryView(
    key: ValueKey(sectionId),
    notebookId: widget.notebookId,
    sectionId: sectionId,
    onOpen: _openPage,
  );
}
