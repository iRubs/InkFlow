import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../shared/providers/database_provider.dart';
import '../../canvas/presentation/canvas_screen.dart';
import '../../editor/presentation/editor_screen.dart';
import '../../pdf/presentation/pdf_annotation_screen.dart';
import 'tag_editor_dialog.dart';

void openNotePage(BuildContext context, Page page) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => switch (page.pageType) {
        'pdf' => PdfAnnotationScreen(page: page),
        'text' || 'mixed' => EditorScreen(page: page),
        _ => CanvasScreen(page: page),
      },
    ),
  );
}

Future<bool> confirmDeletion(
  BuildContext context,
  String title,
  String detail,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(detail),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar definitivamente'),
          ),
        ],
      ),
    ) ??
    false;

class PageLibraryView extends ConsumerStatefulWidget {
  final String? notebookId;
  final String? sectionId;
  final bool favoritesOnly;
  final bool deletedOnly;
  final String? externalQuery;
  final void Function(Page)? onOpen;
  const PageLibraryView({
    super.key,
    this.notebookId,
    this.sectionId,
    this.favoritesOnly = false,
    this.deletedOnly = false,
    this.externalQuery,
    this.onOpen,
  });
  @override
  ConsumerState<PageLibraryView> createState() => _PageLibraryViewState();
}

class _PageLibraryViewState extends ConsumerState<PageLibraryView> {
  final _search = TextEditingController();
  String? _tagId;
  PageSort _sort = PageSort.recent;
  Stream<List<Page>>? _stream;
  Object? _queryKey;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final tags = ref.watch(allTagsProvider).valueOrNull ?? <Tag>[];
    final tag = tags.any((tag) => tag.id == _tagId) ? _tagId : null;
    final query = widget.externalQuery ?? _search.text;
    final key = (
      db,
      widget.notebookId,
      widget.sectionId,
      widget.favoritesOnly,
      widget.deletedOnly,
      query,
      tag,
      _sort,
    );
    if (_queryKey != key) {
      _queryKey = key;
      _stream = db.watchPageLibrary(
        query: query,
        notebookId: widget.notebookId,
        sectionId: widget.sectionId,
        favoritesOnly: widget.favoritesOnly,
        deletedOnly: widget.deletedOnly,
        tagId: tag,
        sort: _sort,
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            children: [
              if (widget.externalQuery == null)
                TextField(
                  key: const ValueKey('library-search'),
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Buscar por título o etiqueta',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar búsqueda',
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(_search.clear),
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              Row(
                children: [
                  const Icon(Icons.sort, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<PageSort>(
                      value: _sort,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                          value: PageSort.recent,
                          child: Text('Más recientes'),
                        ),
                        DropdownMenuItem(
                          value: PageSort.title,
                          child: Text('Título A–Z'),
                        ),
                        DropdownMenuItem(
                          value: PageSort.oldest,
                          child: Text('Más antiguas'),
                        ),
                        DropdownMenuItem(
                          value: PageSort.manual,
                          child: Text('Orden del cuaderno'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _sort = value);
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'Gestionar etiquetas',
                    icon: const Icon(Icons.sell_outlined),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const TagManagerDialog(),
                    ),
                  ),
                ],
              ),
              if (tags.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 96),
                  child: SingleChildScrollView(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 6,
                        children: [
                          FilterChip(
                            label: const Text('Todas'),
                            selected: tag == null,
                            onSelected: (_) => setState(() => _tagId = null),
                          ),
                          ...tags.map(
                            (item) => FilterChip(
                              label: Text(item.name),
                              selected: tag == item.id,
                              onSelected: (selected) => setState(
                                () => _tagId = selected ? item.id : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Page>>(
            stream: _stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'No se pudieron cargar las páginas: ${snapshot.error}',
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final pages = snapshot.data!;
              if (pages.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No hay páginas que coincidan con esta vista.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                itemCount: pages.length,
                itemBuilder: (_, index) =>
                    PageLibraryTile(page: pages[index], onOpen: widget.onOpen),
              );
            },
          ),
        ),
      ],
    );
  }
}

class PageLibraryTile extends ConsumerWidget {
  final Page page;
  final void Function(Page)? onOpen;
  const PageLibraryTile({super.key, required this.page, this.onOpen});
  Future<void> _action(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final db = ref.read(databaseProvider);
    try {
      switch (action) {
        case 'rename':
          final name = await showDialog<String>(
            context: context,
            builder: (_) => NameDialog(
              title: 'Renombrar página',
              initial: page.title,
              maxLength: 200,
            ),
          );
          if (name != null) await db.renamePage(page.id, name);
        case 'tags':
          await showDialog<void>(
            context: context,
            builder: (_) => TagEditorDialog(page: page),
          );
        case 'favorite':
          await db.togglePageFavorite(page.id);
        case 'trash':
          await db.softDeletePage(page.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Página enviada a la papelera.'),
                action: SnackBarAction(
                  label: 'Deshacer',
                  onPressed: () => db.restorePage(page.id),
                ),
              ),
            );
          }
        case 'restore':
          await db.restorePage(page.id);
        case 'delete':
          if (await confirmDeletion(
            context,
            'Eliminar «${page.title}»',
            'Se eliminará esta página y su contenido local. Esta acción no se puede deshacer. Los respaldos que hayas creado se conservan.',
          )) {
            await ref.read(pageDeletionServiceProvider).deletePage(page.id);
          }
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo completar la acción: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(pageTagsProvider(page.id)).valueOrNull ?? <Tag>[];
    final icon = switch (page.pageType) {
      'pdf' => Icons.picture_as_pdf_outlined,
      'text' || 'mixed' => Icons.article_outlined,
      _ => Icons.draw_outlined,
    };
    return Card(
      child: ListTile(
        key: ValueKey('library-page-${page.id}'),
        isThreeLine: tags.isNotEmpty,
        leading: Icon(icon),
        title: Text(page.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          "${page.isDeleted ? 'Eliminada' : 'Actualizada'}: ${(page.deletedAt ?? page.updatedAt).toLocal().toString().substring(0, 16)}${tags.isEmpty ? '' : '\n'}${tags.map((tag) => '#${tag.name}').join('  ')}",
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: page.isDeleted
            ? null
            : () =>
                  onOpen != null ? onOpen!(page) : openNotePage(context, page),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!page.isDeleted)
              IconButton(
                key: ValueKey('page-favorite-${page.id}'),
                tooltip: page.isFavorite
                    ? 'Quitar página de favoritos'
                    : 'Marcar página favorita',
                icon: Icon(
                  page.isFavorite ? Icons.star : Icons.star_border,
                  color: page.isFavorite ? Colors.amber.shade700 : null,
                ),
                onPressed: () => _action(context, ref, 'favorite'),
              )
            else
              IconButton(
                tooltip: 'Restaurar página',
                icon: const Icon(Icons.restore),
                onPressed: () => _action(context, ref, 'restore'),
              ),
            PopupMenuButton<String>(
              key: ValueKey('page-menu-${page.id}'),
              tooltip: 'Acciones de la página',
              onSelected: (action) => _action(context, ref, action),
              itemBuilder: (_) => page.isDeleted
                  ? const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Eliminar definitivamente'),
                      ),
                    ]
                  : const [
                      PopupMenuItem(value: 'rename', child: Text('Renombrar')),
                      PopupMenuItem(
                        value: 'tags',
                        child: Text('Editar etiquetas'),
                      ),
                      PopupMenuItem(
                        value: 'trash',
                        child: Text('Mover página a papelera'),
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

class NameDialog extends StatefulWidget {
  final String title;
  final String initial;
  final int maxLength;
  const NameDialog({
    super.key,
    required this.title,
    required this.initial,
    required this.maxLength,
  });
  @override
  State<NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<NameDialog> {
  late final TextEditingController _input = TextEditingController(
    text: widget.initial,
  );
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _input,
      autofocus: true,
      maxLength: widget.maxLength,
      decoration: const InputDecoration(labelText: 'Nombre'),
      onChanged: (_) => setState(() {}),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _input.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, _input.text.trim()),
        child: const Text('Guardar'),
      ),
    ],
  );
}

class TagManagerDialog extends ConsumerWidget {
  const TagManagerDialog({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(allTagsProvider);
    return AlertDialog(
      title: const Text('Gestionar etiquetas'),
      content: SizedBox(
        width: 460,
        height: 360,
        child: tags.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('$error'),
          data: (items) => items.isEmpty
              ? const Center(
                  child: Text('Añade etiquetas desde el menú de una página.'),
                )
              : ListView(
                  children: items
                      .map(
                        (tag) => ListTile(
                          title: Text(tag.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Renombrar etiqueta',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () async {
                                  final name = await showDialog<String>(
                                    context: context,
                                    builder: (_) => NameDialog(
                                      title: 'Renombrar etiqueta',
                                      initial: tag.name,
                                      maxLength: 40,
                                    ),
                                  );
                                  if (name == null) return;
                                  try {
                                    await ref
                                        .read(databaseProvider)
                                        .renameTag(tag.id, name);
                                  } catch (error) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            SnackBar(content: Text('$error')),
                                          );
                                    }
                                  }
                                },
                              ),
                              IconButton(
                                tooltip: 'Eliminar etiqueta',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  final db = ref.read(databaseProvider);
                                  if (await confirmDeletion(
                                    context,
                                    'Eliminar etiqueta «${tag.name}»',
                                    'Se quitará de todas las páginas. Las páginas y sus apuntes se conservan.',
                                  )) {
                                    await db.deleteTag(tag.id);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
