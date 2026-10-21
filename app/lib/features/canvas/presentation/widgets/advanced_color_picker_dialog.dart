import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../services/palette_manager.dart';

Color? parseInkColor(String input) {
  var value = input.trim().replaceFirst('#', '');
  if (!RegExp(r'^(?:[a-fA-F0-9]{6}|[a-fA-F0-9]{8})$').hasMatch(value)) {
    return null;
  }
  if (value.length == 6) value = 'FF$value';
  return Color(int.parse(value, radix: 16));
}

String inkColorHex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

class AdvancedColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorSelected;
  final PaletteManager? paletteManager;
  const AdvancedColorPickerDialog({
    super.key,
    required this.initialColor,
    required this.onColorSelected,
    this.paletteManager,
  });
  @override
  State<AdvancedColorPickerDialog> createState() =>
      _AdvancedColorPickerDialogState();
}

class _AdvancedColorPickerDialogState extends State<AdvancedColorPickerDialog>
    with SingleTickerProviderStateMixin {
  late Color _color = widget.initialColor;
  late final PaletteManager _manager =
      widget.paletteManager ?? PaletteManager();
  late final TextEditingController _hex = TextEditingController(
    text: inkColorHex(_color),
  );
  late final TabController _tabs = TabController(length: 2, vsync: this);
  String? _error;
  bool _loading = true;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _manager.initialize();
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No se pudieron cargar las paletas: $error');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _hex.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _select(Color color) => setState(() {
    _color = color;
    _hex.text = inkColorHex(color);
    _error = null;
  });
  void _applyHex() {
    final color = parseInkColor(_hex.text);
    if (color == null) {
      setState(() => _error = 'Usa #RRGGBB o #AARRGGBB.');
      return;
    }
    _select(color);
  }

  Future<void> _apply() async {
    setState(() => _saving = true);
    try {
      _manager.addRecentColor(_color);
      await _manager.flush();
      if (!mounted) return;
      widget.onColorSelected(_color);
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _saving = false;
        });
      }
    }
  }

  Future<void> _edit({String? name, List<Color>? colors}) async {
    await showDialog<void>(
      context: context,
      builder: (_) => PaletteEditorDialog(
        manager: _manager,
        previousName: name,
        colors: colors ?? [_color],
        selectedColor: _color,
      ),
    );
  }

  Widget _swatches(List<Color> colors) => Wrap(
    spacing: 4,
    runSpacing: 4,
    children: colors
        .map(
          (color) => Semantics(
            selected: color.toARGB32() == _color.toARGB32(),
            child: IconButton(
              tooltip: inkColorHex(color),
              onPressed: () => _select(color),
              icon: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.toARGB32() == _color.toARGB32()
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                    width: color.toARGB32() == _color.toARGB32() ? 3 : 1,
                  ),
                ),
              ),
            ),
          ),
        )
        .toList(),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _manager,
    builder: (context, _) => AlertDialog(
      title: const Text('Color y paletas'),
      content: SizedBox(
        width: 460,
        height: math.max(
          100,
          math.min(
            500,
            MediaQuery.sizeOf(context).height -
                MediaQuery.viewInsetsOf(context).bottom -
                250,
          ),
        ),
        child: Column(
          children: [
            TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: 'HSV / HEX'),
                Tab(text: 'Mis paletas'),
              ],
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  SingleChildScrollView(
                    child: Column(
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) => ColorPicker(
                            portraitOnly: true,
                            colorPickerWidth: math.min(
                              300,
                              constraints.maxWidth,
                            ),
                            pickerColor: _color,
                            onColorChanged: _select,
                            enableAlpha: true,
                            displayThumbColor: true,
                            labelTypes: const [],
                            pickerAreaHeightPercent: 0.65,
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _hex,
                                decoration: const InputDecoration(
                                  labelText: '#RRGGBB / #AARRGGBB',
                                ),
                                onSubmitted: (_) => _applyHex(),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Aplicar código HEX',
                              onPressed: _applyHex,
                              icon: const Icon(Icons.check),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: _loading || _manager.error != null
                              ? null
                              : () => _edit(),
                          icon: const Icon(Icons.add),
                          label: const Text('Crear paleta'),
                        ),
                        const SizedBox(height: 12),
                        const Text('Colores recientes'),
                        _swatches(_manager.recentColors),
                        for (final entry
                            in _manager.customPalettes.entries) ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Editar paleta ${entry.key}',
                                onPressed: () =>
                                    _edit(name: entry.key, colors: entry.value),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Eliminar paleta ${entry.key}',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(
                                        'Eliminar paleta «${entry.key}»',
                                      ),
                                      content: const Text(
                                        'Las notas que usan estos colores se conservan.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancelar'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Eliminar'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm != true) return;
                                  _manager.deleteCustomPalette(entry.key);
                                  try {
                                    await _manager.flush();
                                  } catch (error) {
                                    if (mounted) {
                                      setState(() => _error = '$error');
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                          _swatches(entry.value),
                        ],
                        const Divider(),
                        for (final entry
                            in _manager.presetPalettes.entries) ...[
                          Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          _swatches(entry.value),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _loading || _saving ? null : _apply,
          child: const Text('Aplicar Color'),
        ),
      ],
    ),
  );
}

class PaletteEditorDialog extends StatefulWidget {
  final PaletteManager manager;
  final String? previousName;
  final List<Color> colors;
  final Color selectedColor;
  const PaletteEditorDialog({
    super.key,
    required this.manager,
    this.previousName,
    required this.colors,
    required this.selectedColor,
  });
  @override
  State<PaletteEditorDialog> createState() => _PaletteEditorDialogState();
}

class _PaletteEditorDialogState extends State<PaletteEditorDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.previousName ?? '',
  );
  final _hex = TextEditingController();
  late final List<Color> _colors = List.of(widget.colors);
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _hex.dispose();
    super.dispose();
  }

  void _add(Color? color) {
    if (_saving) {
      return;
    }
    if (color == null) {
      setState(() => _error = 'Código HEX no válido.');
      return;
    }
    if (_colors.length >= 64) {
      setState(() => _error = 'Máximo 64 colores por paleta.');
      return;
    }
    setState(() {
      if (!_colors.any((item) => item.toARGB32() == color.toARGB32())) {
        _colors.add(color);
      }
      _error = null;
      _hex.clear();
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      widget.manager.replacePalette(widget.previousName, _name.text, _colors);
      await widget.manager.flush();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.previousName == null ? 'Crear paleta' : 'Editar paleta'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('palette-name'),
              controller: _name,
              enabled: !_saving,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Nombre de la paleta',
              ),
              onChanged: (_) => setState(() {}),
            ),
            Wrap(
              spacing: 6,
              children: _colors
                  .map(
                    (color) => InputChip(
                      label: Text(inkColorHex(color)),
                      avatar: CircleAvatar(backgroundColor: color),
                      onDeleted: _saving
                          ? null
                          : () => setState(() => _colors.remove(color)),
                    ),
                  )
                  .toList(),
            ),
            TextButton.icon(
              onPressed: () => _add(widget.selectedColor),
              icon: const Icon(Icons.add),
              label: const Text('Añadir color actual'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('palette-hex'),
                    controller: _hex,
                    decoration: const InputDecoration(
                      labelText: 'Añadir #RRGGBB o #AARRGGBB',
                    ),
                    onSubmitted: (_) => _add(parseInkColor(_hex.text)),
                  ),
                ),
                IconButton(
                  tooltip: 'Añadir color HEX',
                  onPressed: () => _add(parseInkColor(_hex.text)),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
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
        onPressed: _saving || _name.text.trim().isEmpty || _colors.isEmpty
            ? null
            : _save,
        child: const Text('Guardar paleta'),
      ),
    ],
  );
}
