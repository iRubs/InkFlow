import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../data/database/app_database.dart';
import '../../../../shared/providers/database_provider.dart';

/// Tarjeta visual de un cuaderno con diseño tipo libro físico.
class NotebookCard extends ConsumerWidget {
  final Notebook notebook;
  final VoidCallback onTap;

  const NotebookCard({super.key, required this.notebook, required this.onTap});

  Color _parseColor(String hexString) {
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return InkColors.primary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    final coverColor = _parseColor(notebook.coverColor);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final date = notebook.updatedAt.toLocal();
    final formattedDate =
        '${MaterialLocalizations.of(context).formatShortDate(date)} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(date))}';

    return InkWell(
      onTap: onTap,
      borderRadius: InkSpacing.roundedLg,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? InkColors.cardDark : InkColors.cardLight,
          borderRadius: InkSpacing.roundedLg,
          border: Border.all(
            color: isDark ? InkColors.borderDark : InkColors.borderLight,
            width: 1.2,
          ),
          boxShadow: InkSpacing.elevationSm,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Portada superior estilo encuadernación
            Expanded(
              flex: 4,
              child: Container(
                color: coverColor,
                child: Stack(
                  children: [
                    // Efecto de lomo encuadernado lateral
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 14,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                          border: Border(
                            right: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Botón de Favorito en esquina superior derecha
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.25),
                        shape: const CircleBorder(),
                        child: IconButton(
                          iconSize: 20,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            notebook.isFavorite
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: notebook.isFavorite
                                ? Colors.amber
                                : Colors.white70,
                          ),
                          onPressed: () {
                            db.toggleNotebookFavorite(
                              notebook.id,
                              notebook.isFavorite,
                            );
                          },
                        ),
                      ),
                    ),
                    // Etiqueta del título en la portada
                    Positioned(
                      left: 24,
                      right: 16,
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: InkSpacing.roundedSm,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1F000000),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          notebook.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: InkTypography.titleSmall.copyWith(
                            color: InkColors.textPrimaryLight,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Detalles inferiores (fecha y menú de acciones)
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: InkSpacing.md,
                  vertical: InkSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Modificado:',
                            style: InkTypography.labelSmall.copyWith(
                              color: isDark
                                  ? InkColors.textTertiaryDark
                                  : InkColors.textTertiaryLight,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formattedDate,
                            style: InkTypography.bodySmall.copyWith(
                              fontSize: 11,
                              color: isDark
                                  ? InkColors.textSecondaryDark
                                  : InkColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Menú contextual
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 20),
                      onSelected: (value) async {
                        if (value == 'trash') {
                          await db.softDeleteNotebook(notebook.id);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'trash',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: Colors.red,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Mover a papelera',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
