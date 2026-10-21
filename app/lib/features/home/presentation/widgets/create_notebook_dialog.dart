import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../data/database/app_database.dart';
import '../../../../shared/providers/database_provider.dart';

/// Diálogo para crear un nuevo cuaderno con título y color de portada.
class CreateNotebookDialog extends ConsumerStatefulWidget {
  const CreateNotebookDialog({super.key});

  @override
  ConsumerState<CreateNotebookDialog> createState() =>
      _CreateNotebookDialogState();
}

class _CreateNotebookDialogState extends ConsumerState<CreateNotebookDialog> {
  final _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  static const _uuid = Uuid();

  // Opciones de colores de portada para el cuaderno
  final List<String> _coverColors = [
    '#2563EB', // Azul clásico
    '#0D9488', // Verde azulado / Teal
    '#059669', // Esmeralda
    '#D97706', // Ámbar / Cuero
    '#DC2626', // Rubí / Rojo
    '#7C3AED', // Violeta intenso
    '#DB2777', // Fucsia
    '#374151', // Carbón / Grafito
  ];

  late String _selectedColor;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedColor = _coverColors.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Color _parseHex(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      final db = ref.read(databaseProvider);
      final notebookId = _uuid.v4();
      final sectionId = _uuid.v4();
      final pageId = _uuid.v4();
      final now = DateTime.now();

      // 1. Crear cuaderno
      await db.insertNotebook(
        NotebooksCompanion(
          id: drift.Value(notebookId),
          title: drift.Value(_titleController.text.trim()),
          coverColor: drift.Value(_selectedColor),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );

      // 2. Crear sección inicial predeterminada
      await db.insertSection(
        SectionsCompanion(
          id: drift.Value(sectionId),
          notebookId: drift.Value(notebookId),
          title: const drift.Value('General'),
          sortOrder: const drift.Value(0),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );

      // 3. Crear primera página lista para escribir/dibujar
      await db.insertPage(
        PagesCompanion(
          paperSize: const drift.Value('Infinite'),
          id: drift.Value(pageId),
          sectionId: drift.Value(sectionId),
          title: const drift.Value('Página 1'),
          pageType: const drift.Value('canvas'),
          templateId: const drift.Value('ruled'),
          paperColor: const drift.Value('#FFFFFF'),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );

      if (mounted) {
        Navigator.of(context).pop(notebookId);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: InkSpacing.roundedLg),
      backgroundColor: isDark ? InkColors.surfaceDark : InkColors.surfaceLight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(InkSpacing.xxl),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _parseHex(_selectedColor)
                            .withValues(alpha: 0.15),
                        borderRadius: InkSpacing.roundedSm,
                      ),
                      child: Icon(
                        Icons.book_rounded,
                        color: _parseHex(_selectedColor),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Nuevo Cuaderno',
                      style: InkTypography.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: InkSpacing.xl),
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Título del Cuaderno',
                    hintText: 'Ej. Apuntes de Física, Ideas de Proyecto',
                    border: OutlineInputBorder(
                      borderRadius: InkSpacing.roundedMd,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingresa un título para el cuaderno';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: InkSpacing.lg),
                const Text(
                  'Color de Portada',
                  style: InkTypography.labelMedium,
                ),
                const SizedBox(height: InkSpacing.sm),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _coverColors.map((colorHex) {
                    final color = _parseHex(colorHex);
                    final isSelected = _selectedColor == colorHex;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = colorHex),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : Colors.transparent,
                            width: 2.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.6),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: InkSpacing.xxl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : _handleCreate,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Crear Cuaderno'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
