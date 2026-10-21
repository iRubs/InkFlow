import '../../canvas/services/font_manager.dart';
import '../../canvas/services/palette_manager.dart';

import 'package:file_picker/file_picker.dart';

import '../../../core/storage/atomic_json_store.dart';
import '../../../core/app_version.dart';
import '../../../core/theme/theme_preference.dart';
import '../../backup/services/backup_service.dart';
import '../../export/presentation/widgets/export_dialog.dart';
import '../../library/presentation/page_library_view.dart';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../data/database/app_database.dart';
import '../../../shared/providers/database_provider.dart';
import '../../notebook/presentation/notebook_screen.dart';
import 'widgets/create_notebook_dialog.dart';
import 'widgets/notebook_card.dart';

/// Pantalla Principal (Home) de InkFlow.
/// Ofrece una experiencia responsiva adaptada a Samsung Galaxy Tab (10.9") y Windows Desktop.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  bool _showPages = false;
  bool _recoveringDeletions = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await ref.read(pageDeletionServiceProvider).recoverPendingDeletions();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Hay una eliminación pendiente de recuperar: $error',
              ),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _recoveringDeletions = false);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCreateNotebookDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreateNotebookDialog(),
    ).then((newNotebookId) {
      if (newNotebookId != null && mounted) {
        _openNotebook(newNotebookId as String);
      }
    });
  }

  void _openNotebook(String notebookId) {
    ref.read(selectedNotebookIdProvider.notifier).state = notebookId;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NotebookScreen(notebookId: notebookId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navIndex = ref.watch(navigationIndexProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTabletOrDesktop = screenWidth >= 640;

    return Scaffold(
      body: Row(
        children: [
          // Barra lateral de navegación (en tablet y escritorio)
          if (isTabletOrDesktop)
            NavigationRail(
              selectedIndex: navIndex,
              onDestinationSelected: (index) {
                ref.read(navigationIndexProvider.notifier).state = index;
              },
              extended: screenWidth >= 900,
              minExtendedWidth: InkSpacing.sidebarExpandedWidth,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: InkSpacing.lg),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: InkColors.primary,
                        borderRadius: InkSpacing.roundedSm,
                      ),
                      child: const Icon(
                        Icons.draw_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    if (screenWidth >= 900) ...[
                      const SizedBox(width: 12),
                      Text(
                        'InkFlow',
                        style: InkTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.book_outlined),
                  selectedIcon: Icon(Icons.book_rounded),
                  label: Text('Cuadernos'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.star_outline_rounded),
                  selectedIcon: Icon(Icons.star_rounded),
                  label: Text('Favoritos'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.delete_outline_rounded),
                  selectedIcon: Icon(Icons.delete_rounded),
                  label: Text('Papelera'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: Text('Ajustes'),
                ),
              ],
            ),
          // Separador vertical
          if (isTabletOrDesktop)
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: isDark ? InkColors.dividerDark : InkColors.dividerLight,
            ),
          // Contenido principal según la pestaña activa
          Expanded(
            child: Column(
              children: [
                _buildHeader(isTabletOrDesktop, isDark),
                Expanded(child: _buildBodyContent(navIndex, isDark)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: !isTabletOrDesktop
          ? NavigationBar(
              selectedIndex: navIndex,
              onDestinationSelected: (index) {
                ref.read(navigationIndexProvider.notifier).state = index;
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.book_outlined),
                  selectedIcon: Icon(Icons.book_rounded),
                  label: 'Cuadernos',
                ),
                NavigationDestination(
                  icon: Icon(Icons.star_outline_rounded),
                  selectedIcon: Icon(Icons.star_rounded),
                  label: 'Favoritos',
                ),
                NavigationDestination(
                  icon: Icon(Icons.delete_outline_rounded),
                  selectedIcon: Icon(Icons.delete_rounded),
                  label: 'Papelera',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: 'Ajustes',
                ),
              ],
            )
          : null,
      floatingActionButton: navIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _openCreateNotebookDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nuevo Cuaderno'),
            )
          : null,
    );
  }

  Widget _buildHeader(bool isTabletOrDesktop, bool isDark) {
    final navIndex = ref.watch(navigationIndexProvider);
    final titles = [
      'Mis Cuadernos',
      'Favoritos',
      'Papelera de Reciclaje',
      'Ajustes',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: InkSpacing.xxl,
        vertical: InkSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: isDark ? InkColors.surfaceDark : InkColors.surfaceLight,
        border: Border(
          bottom: BorderSide(
            color: isDark ? InkColors.borderDark : InkColors.borderLight,
            width: 1,
          ),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: isTabletOrDesktop ? 180 : 260,
            child: Text(
              titles[navIndex],
              style: InkTypography.displayMedium.copyWith(fontSize: 22),
            ),
          ),
          if (navIndex != 3) ...[
            SizedBox(
              width: isTabletOrDesktop ? 240 : 260,
              height: 48,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar páginas...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: InkSpacing.roundedFull,
                    borderSide: BorderSide(
                      color: isDark
                          ? InkColors.borderDark
                          : InkColors.borderLight,
                    ),
                  ),
                ),
                onChanged: (val) {
                  setState(() => _isSearching = val.trim().isNotEmpty);
                },
              ),
            ),
            const SizedBox(width: InkSpacing.md),
          ],
          if (navIndex == 0 && isTabletOrDesktop)
            FilledButton.icon(
              onPressed: _openCreateNotebookDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nuevo Cuaderno'),
            ),
        ],
      ),
    );
  }

  Widget _buildBodyContent(int navIndex, bool isDark) {
    if (_recoveringDeletions) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_isSearching && _searchController.text.trim().isNotEmpty) {
      return PageLibraryView(externalQuery: _searchController.text.trim());
    }
    switch (navIndex) {
      case 0:
      case 1:
      case 2:
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Cuadernos'),
                    icon: Icon(Icons.book_outlined),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Páginas'),
                    icon: Icon(Icons.description_outlined),
                  ),
                ],
                selected: {_showPages},
                onSelectionChanged: (value) =>
                    setState(() => _showPages = value.first),
              ),
            ),
            Expanded(
              child: _showPages
                  ? PageLibraryView(
                      key: ValueKey('global-pages-$navIndex'),
                      favoritesOnly: navIndex == 1,
                      deletedOnly: navIndex == 2,
                    )
                  : switch (navIndex) {
                      1 => _buildNotebooksList(
                        favoriteNotebooksProvider,
                        'No tienes cuadernos en favoritos',
                      ),
                      2 => _buildTrashList(isDark),
                      _ => _buildNotebooksList(
                        activeNotebooksProvider,
                        'No hay cuadernos aún',
                      ),
                    },
            ),
          ],
        );
      case 3:
        return _buildSettingsView(isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNotebooksList(
    StreamProvider<List<Notebook>> provider,
    String emptyMessage,
  ) {
    final notebooksAsync = ref.watch(provider);

    return notebooksAsync.when(
      data: (notebooks) {
        if (notebooks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_stories_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(emptyMessage, style: InkTypography.titleMedium),
                const SizedBox(height: 8),
                const Text(
                  'Crea tu primer cuaderno para comenzar a escribir con el S Pen.',
                  style: InkTypography.bodyMedium,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _openCreateNotebookDialog,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Crear Cuaderno'),
                ),
              ],
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            int crossAxisCount = 2;
            if (width >= 1200) {
              crossAxisCount = 5;
            } else if (width >= 900) {
              crossAxisCount = 4;
            } else if (width >= 600) {
              crossAxisCount = 3;
            }

            return GridView.builder(
              padding: const EdgeInsets.all(InkSpacing.xxl),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: InkSpacing.lg,
                mainAxisSpacing: InkSpacing.lg,
                childAspectRatio: 0.72, // Proporción áurea de cuaderno físico
              ),
              itemCount: notebooks.length,
              itemBuilder: (context, index) {
                final notebook = notebooks[index];
                return NotebookCard(
                  notebook: notebook,
                  onTap: () => _openNotebook(notebook.id),
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) =>
          Center(child: Text('Error al cargar cuadernos: $err')),
    );
  }

  Widget _buildTrashList(bool isDark) {
    final trashAsync = ref.watch(trashNotebooksProvider);
    final db = ref.read(databaseProvider);

    return trashAsync.when(
      data: (notebooks) {
        if (notebooks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                const Text(
                  'La papelera está vacía',
                  style: InkTypography.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Los cuadernos eliminados se conservan aquí antes de ser borrados definitivamente.',
                  style: InkTypography.bodyMedium,
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(InkSpacing.xxl),
          itemCount: notebooks.length,
          separatorBuilder: (_, __) => const SizedBox(height: InkSpacing.md),
          itemBuilder: (context, index) {
            final notebook = notebooks[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.book_rounded, color: Colors.grey),
                title: Text(notebook.title, style: InkTypography.titleMedium),
                subtitle: Text('Eliminado el: ${notebook.deletedAt ?? ''}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.restore_rounded),
                      label: const Text('Restaurar'),
                      onPressed: () => db.restoreNotebook(notebook.id),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_forever_rounded,
                        color: Colors.red,
                      ),
                      tooltip: 'Eliminar definitivamente',
                      onPressed: () async {
                        if (await confirmDeletion(
                          context,
                          'Eliminar «${notebook.title}»',
                          'Se eliminarán el cuaderno, sus páginas y su contenido local. Esta acción no se puede deshacer. Los respaldos existentes se conservan.',
                        )) {
                          try {
                            await ref
                                .read(pageDeletionServiceProvider)
                                .deleteNotebook(notebook.id);
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('No se pudo eliminar: $error'),
                                ),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Future<void> _restoreBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['inkflow'],
    );
    if (!mounted || result?.files.single.path == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar datos de InkFlow'),
        content: const Text(
          'Se reemplazarán los cuadernos y notas actuales por el respaldo. La carpeta anterior se conserva junto a InkFlowData para recuperación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 24),
              Text('Restaurando datos…'),
            ],
          ),
        ),
      ),
    );
    var success = false;
    try {
      await AtomicJsonStore.flush();
      await ref.read(databaseProvider).close();
      success = await BackupService().restoreBackup(
        backupZipPath: result!.files.single.path!,
      );
    } finally {
      FontManager().reset();
      PaletteManager().reset();
      ref.invalidate(databaseProvider);
      ref.invalidate(themeModeProvider);
      if (mounted) {
        navigator.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Respaldo restaurado.' : 'No se restauró: archivo inválido, incompatible o sin integridad.',
            ),
          ),
        );
      }
    }
  }

  Widget _buildSettingsView(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(InkSpacing.xxl),
      children: [
        const Text('Preferencias de InkFlow', style: InkTypography.titleLarge),
        const SizedBox(height: InkSpacing.lg),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: const Text('Crear respaldo completo'),
                subtitle: const Text(
                  'Guardar cuadernos, notas y adjuntos en un archivo .inkflow',
                ),
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => const ExportDialog(
                    pageTitle: 'InkFlow',
                    backupOnly: true,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Restaurar respaldo'),
                subtitle: const Text(
                  'Reemplaza los datos actuales y conserva una copia anterior',
                ),
                onTap: _restoreBackup,
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Licencias de código abierto'),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'InkFlow',
                  applicationVersion: inkFlowVersion,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: InkSpacing.lg),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Tema de la Aplicación'),
                trailing: DropdownButton<ThemeMode>(
                  value: ref.watch(themeModeProvider),
                  onChanged: (value) async {
                    if (value == null) return;
                    try {
                      await ref.read(themeModeProvider.notifier).select(value);
                    } catch (error) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('No se pudo guardar el tema: $error'),
                          ),
                        );
                      }
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('Sistema'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Claro'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Oscuro'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.draw_outlined),
                title: Text('Sensibilidad del S Pen / Stylus'),
                subtitle: Text('Sensibilidad a presión y suavizado activo'),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.cloud_off_rounded),
                title: Text('Privacidad & Datos Locales'),
                subtitle: Text(
                  '100% On-Device. Cero datos enviados a terceros.',
                ),
                trailing: Icon(Icons.check_circle_rounded, color: Colors.green),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
