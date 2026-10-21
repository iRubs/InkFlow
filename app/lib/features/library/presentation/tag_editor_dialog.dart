import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../shared/providers/database_provider.dart';

class TagEditorDialog extends ConsumerStatefulWidget {
  final Page page;
  const TagEditorDialog({super.key, required this.page});
  @override
  ConsumerState<TagEditorDialog> createState() => _TagEditorDialogState();
}

class _TagEditorDialogState extends ConsumerState<TagEditorDialog> {
  final _input = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tags = await ref
          .read(databaseProvider)
          .watchTagsForPage(widget.page.id)
          .first;
      if (mounted) {
        setState(() {
          _input.text = tags.map((tag) => tag.name).join(', ');
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(databaseProvider)
          .setPageTags(widget.page.id, _input.text.split(','));
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(allTagsProvider).valueOrNull ?? <Tag>[];
    final selected = _input.text
        .split(',')
        .map((name) => name.trim().toLowerCase())
        .toSet();
    return AlertDialog(
      title: const Text('Etiquetas de la página'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.page.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              if (_loading) const LinearProgressIndicator(),
              TextField(
                key: const ValueKey('page-tags-input'),
                controller: _input,
                enabled: !_loading && !_saving,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Etiquetas separadas por comas',
                  hintText: 'Universidad, Matemáticas, Parcial 1',
                  helperText: 'Hasta 12 etiquetas; 40 caracteres por etiqueta.',
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: tags
                    .map(
                      (tag) => FilterChip(
                        label: Text(tag.name),
                        selected: selected.contains(tag.name.toLowerCase()),
                        onSelected: _loading || _saving
                            ? null
                            : (add) {
                                final names = _input.text
                                    .split(',')
                                    .map((name) => name.trim())
                                    .where((name) => name.isNotEmpty)
                                    .toList();
                                names.removeWhere(
                                  (name) =>
                                      name.toLowerCase() ==
                                      tag.name.toLowerCase(),
                                );
                                if (add) names.add(tag.name);
                                setState(() => _input.text = names.join(', '));
                              },
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _loading || _saving ? null : _save,
          child: Text(_saving ? 'Guardando…' : 'Guardar etiquetas'),
        ),
      ],
    );
  }
}
