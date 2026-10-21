import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Información de una familia tipográfica disponible en InkFlow.
class InkFontFamily {
  final String name;
  final String displayName;
  final bool isBundled;
  final String? localFilePath;

  const InkFontFamily({
    required this.name,
    required this.displayName,
    this.isBundled = false,
    this.localFilePath,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'displayName': displayName,
    'isBundled': isBundled,
    'localFilePath': localFilePath,
  };

  factory InkFontFamily.fromJson(Map<String, dynamic> json) => InkFontFamily(
    name: json['name'] as String,
    displayName: json['displayName'] as String,
    isBundled: json['isBundled'] as bool? ?? false,
    localFilePath: json['localFilePath'] as String?,
  );
}

/// Gestor de fuentes tipográficas libres e importación dinámica (.ttf/.otf).
class FontManager {
  static final FontManager _instance = FontManager._internal();
  factory FontManager() => _instance;
  FontManager._internal();

  /// Fuentes libres incluidas de fábrica en el paquete InkFlow (OFL / Apache)
  final List<InkFontFamily> _bundledFonts = const [
    InkFontFamily(
      name: 'Caveat',
      displayName: 'Caveat (Cursiva Elegante)',
      isBundled: true,
    ),
    InkFontFamily(
      name: 'PatrickHand',
      displayName: 'Patrick Hand (Manuscrita)',
      isBundled: true,
    ),
    InkFontFamily(
      name: 'FiraCode',
      displayName: 'Fira Code (Código / Mono)',
      isBundled: true,
    ),
  ];

  final List<InkFontFamily> _customFonts = [];
  bool _initialized = false;
  Directory? _fontsDirectory;

  List<InkFontFamily> get availableFonts => [..._bundledFonts, ..._customFonts];

  void reset() {
    _initialized = false;
    _customFonts.clear();
  }

  /// Inicializa y carga en caliente todas las fuentes importadas por el usuario
  Future<void> initialize({Directory? baseDirectory}) async {
    if (_initialized) return;
    try {
      final appDir = baseDirectory ?? await getApplicationDocumentsDirectory();
      _fontsDirectory = Directory(p.join(appDir.path, 'InkFlowData', 'fonts'));
      if (!await _fontsDirectory!.exists()) {
        await _fontsDirectory!.create(recursive: true);
      }

      final configFile = File(
        p.join(_fontsDirectory!.path, 'imported_fonts.json'),
      );
      if (await configFile.exists()) {
        final content = await configFile.readAsString();
        if (content.isNotEmpty) {
          final list = (jsonDecode(content) as List)
              .map(
                (item) => InkFontFamily.fromJson(item as Map<String, dynamic>),
              )
              .toList();

          for (final font in list) {
            if (font.localFilePath != null) {
              final fontFile = File(font.localFilePath!);
              if (await fontFile.exists()) {
                await _loadFontFromFile(font.name, fontFile);
                _customFonts.add(font);
              }
            }
          }
        }
      }
      _initialized = true;
    } catch (e) {
      debugPrint('Error al inicializar FontManager: $e');
    }
  }

  /// Permite al usuario seleccionar un archivo de fuente (.ttf o .otf) e importarlo
  Future<InkFontFamily?> importFontFromFilePicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ttf', 'otf'],
      );

      if (result == null || result.files.single.path == null) {
        return null;
      }

      final sourceFile = File(result.files.single.path!);
      final fileName = p.basenameWithoutExtension(sourceFile.path);
      final extension = p.extension(sourceFile.path);

      // Normalizar nombre de familia tipográfica
      final familyName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      if (_fontsDirectory == null) {
        final appDir = await getApplicationDocumentsDirectory();
        _fontsDirectory = Directory(
          p.join(appDir.path, 'InkFlowData', 'fonts'),
        );
        if (!await _fontsDirectory!.exists()) {
          await _fontsDirectory!.create(recursive: true);
        }
      }

      final destPath = p.join(_fontsDirectory!.path, '$familyName$extension');
      final savedFile = await sourceFile.copy(destPath);

      // Cargar dinámicamente en el motor de renderizado de Flutter
      await _loadFontFromFile(familyName, savedFile);

      final newFont = InkFontFamily(
        name: familyName,
        displayName: fileName,
        isBundled: false,
        localFilePath: destPath,
      );

      _customFonts.removeWhere((f) => f.name == familyName);
      _customFonts.add(newFont);
      await _saveCustomFontsConfig();

      return newFont;
    } catch (e) {
      debugPrint('Error al importar fuente: $e');
      return null;
    }
  }

  Future<void> _loadFontFromFile(String familyName, File file) async {
    try {
      final bytes = await file.readAsBytes();
      final fontLoader = FontLoader(familyName);
      fontLoader.addFont(Future.value(ByteData.sublistView(bytes)));
      await fontLoader.load();
    } catch (e) {
      debugPrint('Error al registrar FontLoader para $familyName: $e');
    }
  }

  Future<void> _saveCustomFontsConfig() async {
    if (_fontsDirectory == null) return;
    try {
      final configFile = File(
        p.join(_fontsDirectory!.path, 'imported_fonts.json'),
      );
      final jsonStr = jsonEncode(_customFonts.map((f) => f.toJson()).toList());
      await configFile.writeAsString(jsonStr);
    } catch (e) {
      debugPrint('Error al guardar configuración de fuentes: $e');
    }
  }
}
