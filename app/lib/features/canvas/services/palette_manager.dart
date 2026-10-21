import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/storage/atomic_json_store.dart';

import 'package:flutter/material.dart';

/// Gestor de paletas de colores ilimitadas para el lienzo de InkFlow.
///
/// Soporta:
/// - Historial FIFO de colores recientemente utilizados.
/// - Paletas predefinidas por categorías (Clásica, Pastel, Neón/Resaltador, Tierra).
/// - Creación y persistencia de paletas personalizadas del usuario.
class PaletteManager extends ChangeNotifier {
  static final PaletteManager _instance = PaletteManager._internal();
  factory PaletteManager() => _instance;
  PaletteManager._internal();
  PaletteManager.detached();
  File? _file;
  Future<void>? _initialization;
  Future<void> _pendingWrite = Future.value();
  Object? _error;
  bool _loadFailed = false;
  bool _ready = false;
  int _revision = 0;
  Object? get error => _error;

  Future<void> initialize({Directory? baseDirectory}) =>
      _initialization ??= _load(baseDirectory);
  Future<void> _load(Directory? baseDirectory) async {
    try {
      final docs = baseDirectory ?? await getApplicationDocumentsDirectory();
      _file = File(
        p.join(docs.path, 'InkFlowData', 'preferences', 'palettes.json'),
      );
      final data = await AtomicJsonStore.read(_file!);
      if (data != null) {
        final palettes = _parsePalettes(data['palettes']);
        final recent = _parseColors(data['recent'], allowEmpty: true);
        if (_revision == 0) {
          _customPalettes
            ..clear()
            ..addAll(palettes);
          _recentColors
            ..clear()
            ..addAll(recent.take(maxRecentColors));
        } else {
          final pending = Map<String, List<Color>>.of(_customPalettes);
          _customPalettes
            ..clear()
            ..addAll(palettes)
            ..addAll(pending);
          final seen = <int>{};
          final merged = [..._recentColors, ...recent]
              .where((color) => seen.add(color.toARGB32()))
              .take(maxRecentColors)
              .toList();
          _recentColors
            ..clear()
            ..addAll(merged);
        }
      }
      _error = null;
      _ready = true;
      notifyListeners();
      if (_revision > 0) _persist();
    } catch (error) {
      _error = error;
      _loadFailed = true;
      notifyListeners();
      rethrow;
    }
  }

  static List<Color> _parseColors(dynamic value, {bool allowEmpty = false}) {
    if (value is! List ||
        (!allowEmpty && value.isEmpty) ||
        value.length > 64 ||
        value.any((item) => item is! int || item < 0 || item > 0xffffffff)) {
      throw const FormatException('Lista de colores no válida.');
    }
    final seen = <int>{};
    return value.cast<int>().where(seen.add).map(Color.new).toList();
  }

  static Map<String, List<Color>> _parsePalettes(dynamic value) {
    if (value is! Map) throw const FormatException('Paletas no válidas.');
    final result = <String, List<Color>>{};
    final names = <String>{};
    for (final entry in value.entries) {
      if (entry.key is! String ||
          (entry.key as String).trim().isEmpty ||
          (entry.key as String).trim().length > 60 ||
          !names.add((entry.key as String).trim().toLowerCase())) {
        throw const FormatException('Nombre de paleta no válido o duplicado.');
      }
      result[(entry.key as String).trim()] = _parseColors(entry.value);
    }
    return result;
  }

  void _persist() {
    _revision++;
    notifyListeners();
    if (_file == null || _loadFailed || !_ready) return;
    _pendingWrite =
        AtomicJsonStore.write(_file!, {
          'version': 1,
          'recent': _recentColors.map((color) => color.toARGB32()).toList(),
          'palettes': {
            for (final entry in _customPalettes.entries)
              entry.key: entry.value.map((color) => color.toARGB32()).toList(),
          },
        }).then(
          (_) {
            _error = null;
          },
          onError: (Object error) {
            _error = error;
            notifyListeners();
          },
        );
  }

  Future<void> flush() async {
    if (_initialization != null) await _initialization;
    await _pendingWrite;
    if (_error != null) {
      throw StateError('No se pudieron guardar las paletas: $_error');
    }
  }

  void reset() {
    _file = null;
    _initialization = null;
    _error = null;
    _loadFailed = false;
    _ready = false;
    _customPalettes.clear();
    _recentColors
      ..clear()
      ..addAll(_presetPalettes['Clásica']!);
    _revision = 0;
    notifyListeners();
  }

  static const int maxRecentColors = 10;
  final List<Color> _recentColors = [
    const Color(0xFF0F172A), // Negro Tinta
    const Color(0xFF2563EB), // Azul Real
    const Color(0xFF059669), // Verde Esmeralda
    const Color(0xFFDC2626), // Rojo Carmesí
    const Color(0xFFD97706), // Ámbar
    const Color(0xFF7C3AED), // Púrpura
  ];

  final Map<String, List<Color>> _presetPalettes = {
    'Clásica': const [
      Color(0xFF0F172A),
      Color(0xFF334155),
      Color(0xFF1E3A8A),
      Color(0xFF14532D),
      Color(0xFF7F1D1D),
      Color(0xFF701A75),
    ],
    'Pastel': const [
      Color(0xFFFDE68A),
      Color(0xFFFBCFE8),
      Color(0xFFA7F3D0),
      Color(0xFFBAE6FD),
      Color(0xFFDDD6FE),
      Color(0xFFFED7AA),
    ],
    'Neón & Resaltador': const [
      Color(0xFFFEF08A),
      Color(0xFF86EFAC),
      Color(0xFF67E8F9),
      Color(0xFFF472B6),
      Color(0xFFA78BFA),
      Color(0xFFFB923C),
    ],
    'Tierra & Naturaleza': const [
      Color(0xFF78350F),
      Color(0xFF92400E),
      Color(0xFF3F6212),
      Color(0xFF155E75),
      Color(0xFF581C87),
      Color(0xFF831843),
    ],
  };

  final Map<String, List<Color>> _customPalettes = {};

  List<Color> get recentColors => List.unmodifiable(_recentColors);
  Map<String, List<Color>> get presetPalettes => Map.unmodifiable(
    _presetPalettes.map(
      (name, colors) => MapEntry(name, List<Color>.unmodifiable(colors)),
    ),
  );
  Map<String, List<Color>> get customPalettes => Map.unmodifiable(
    _customPalettes.map(
      (name, colors) => MapEntry(name, List<Color>.unmodifiable(colors)),
    ),
  );

  /// Registra un color en el historial de recientes evitando duplicados contiguos
  void addRecentColor(Color color) {
    _recentColors.removeWhere((c) => c.toARGB32() == color.toARGB32());
    _recentColors.insert(0, color);
    if (_recentColors.length > maxRecentColors) {
      _recentColors.removeLast();
    }
    _persist();
  }

  /// Guarda una nueva paleta personalizada creada por el usuario
  void saveCustomPalette(String name, List<Color> colors) {
    final normalized = name.trim();
    final parsed = _parsePalettes({
      normalized: colors.map((color) => color.toARGB32()).toList(),
    });
    final existing = _customPalettes.keys
        .where((key) => key.toLowerCase() == normalized.toLowerCase())
        .firstOrNull;
    _customPalettes[existing ?? normalized] = parsed[normalized]!;
    _persist();
  }

  void replacePalette(String? previousName, String name, List<Color> colors) {
    final normalized = name.trim();
    final parsed = _parsePalettes({
      normalized: colors.map((color) => color.toARGB32()).toList(),
    });
    if (_customPalettes.keys.any(
      (key) =>
          key != previousName && key.toLowerCase() == normalized.toLowerCase(),
    )) {
      throw ArgumentError('Ya existe una paleta con ese nombre.');
    }
    if (previousName != null) _customPalettes.remove(previousName);
    _customPalettes[normalized] = parsed[normalized]!;
    _persist();
  }

  void deleteCustomPalette(String name) {
    _customPalettes.remove(name);
    _persist();
  }

  /// Serializa las paletas personalizadas para almacenamiento persistente
  String exportCustomPalettesJson() {
    final map = <String, List<int>>{};
    for (final entry in _customPalettes.entries) {
      map[entry.key] = entry.value.map((c) => c.toARGB32()).toList();
    }
    return jsonEncode(map);
  }

  /// Restaura las paletas personalizadas desde JSON
  void importCustomPalettesJson(String jsonStr) {
    final parsed = _parsePalettes(jsonDecode(jsonStr));
    for (final entry in parsed.entries) {
      _customPalettes.removeWhere(
        (name, _) => name.toLowerCase() == entry.key.toLowerCase(),
      );
      _customPalettes[entry.key] = entry.value;
    }
    _persist();
  }
}
