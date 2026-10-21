import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Representa un sticker disponible en la biblioteca.
class StickerItem {
  final String id;
  final String name;
  final String
  category; // 'educacion', 'organizacion', 'decoracion', 'personal'
  final String? assetPath;
  final String? filePath;
  final bool isCustom;

  const StickerItem({
    required this.id,
    required this.name,
    required this.category,
    this.assetPath,
    this.filePath,
    this.isCustom = false,
  });
}

/// Gestor de biblioteca de stickers libres, personalizados e importación de packs.
class StickerManager {
  static final StickerManager _instance = StickerManager._internal();
  factory StickerManager() => _instance;
  StickerManager._internal();

  static const _uuid = Uuid();
  Directory? _customStickersDir;
  final List<StickerItem> _customStickers = [];

  /// Stickers libres incluidos de fábrica
  final List<StickerItem> _bundledStickers = const [
    // Educación
    StickerItem(
      id: 'b-edu-1',
      name: 'Excelente',
      category: 'educacion',
      assetPath: 'assets/stickers/educacion/excelente.svg',
    ),
    StickerItem(
      id: 'b-edu-2',
      name: 'Revisado',
      category: 'educacion',
      assetPath: 'assets/stickers/educacion/revisado.svg',
    ),
    StickerItem(
      id: 'b-edu-3',
      name: 'Aprobado 10/10',
      category: 'educacion',
      assetPath: 'assets/stickers/educacion/aprobado.svg',
    ),
    StickerItem(
      id: 'b-edu-4',
      name: 'Pendiente',
      category: 'educacion',
      assetPath: 'assets/stickers/educacion/pendiente.svg',
    ),

    // Organización
    StickerItem(
      id: 'b-org-1',
      name: 'Urgente',
      category: 'organizacion',
      assetPath: 'assets/stickers/organizacion/urgente.svg',
    ),
    StickerItem(
      id: 'b-org-2',
      name: 'Importante',
      category: 'organizacion',
      assetPath: 'assets/stickers/organizacion/importante.svg',
    ),
    StickerItem(
      id: 'b-org-3',
      name: 'Idea',
      category: 'organizacion',
      assetPath: 'assets/stickers/organizacion/idea.svg',
    ),
    StickerItem(
      id: 'b-org-4',
      name: 'Meta',
      category: 'organizacion',
      assetPath: 'assets/stickers/organizacion/meta.svg',
    ),
    StickerItem(
      id: 'b-org-5',
      name: 'Tareas',
      category: 'organizacion',
      assetPath: 'assets/stickers/organizacion/checklist.svg',
    ),

    // Decoración
    StickerItem(
      id: 'b-dec-1',
      name: 'Estrella Dorada',
      category: 'decoracion',
      assetPath: 'assets/stickers/decoracion/estrella_dorada.svg',
    ),
    StickerItem(
      id: 'b-dec-2',
      name: 'Corazón',
      category: 'decoracion',
      assetPath: 'assets/stickers/decoracion/corazon.svg',
    ),
    StickerItem(
      id: 'b-dec-3',
      name: 'Flecha Curva',
      category: 'decoracion',
      assetPath: 'assets/stickers/decoracion/flecha_curva.svg',
    ),
    StickerItem(
      id: 'b-dec-4',
      name: 'Washi Tape Pastel',
      category: 'decoracion',
      assetPath: 'assets/stickers/decoracion/washi_tape_pastel.svg',
    ),
    StickerItem(
      id: 'b-dec-5',
      name: 'Chincheta',
      category: 'decoracion',
      assetPath: 'assets/stickers/decoracion/chincheta.svg',
    ),
  ];

  List<StickerItem> get bundledStickers => List.unmodifiable(_bundledStickers);
  List<StickerItem> get customStickers => List.unmodifiable(_customStickers);

  Future<void> initialize({Directory? baseDirectory}) async {
    try {
      final appDir = baseDirectory ?? await getApplicationDocumentsDirectory();
      _customStickersDir = Directory(
        p.join(appDir.path, 'InkFlowData', 'stickers', 'custom'),
      );
      if (!await _customStickersDir!.exists()) {
        await _customStickersDir!.create(recursive: true);
      }

      await refreshCustomStickers();
    } catch (e) {
      debugPrint('Error al inicializar StickerManager: $e');
    }
  }

  Future<void> refreshCustomStickers() async {
    if (_customStickersDir == null || !await _customStickersDir!.exists()) {
      return;
    }
    _customStickers.clear();
    final entities = await _customStickersDir!.list().toList();
    for (final entity in entities) {
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (ext == '.png' ||
            ext == '.jpg' ||
            ext == '.jpeg' ||
            ext == '.svg' ||
            ext == '.webp') {
          final name = p.basenameWithoutExtension(entity.path);
          _customStickers.add(
            StickerItem(
              id: 'custom-${_customStickers.length}',
              name: name,
              category: 'personal',
              filePath: entity.path,
              isCustom: true,
            ),
          );
        }
      }
    }
  }

  /// Importa una imagen como sticker personalizado desde el explorador de archivos
  Future<StickerItem?> importStickerFromImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);

      if (result == null || result.files.single.path == null) {
        return null;
      }

      final sourceFile = File(result.files.single.path!);
      final fileName = p.basename(sourceFile.path);

      if (_customStickersDir == null) {
        final appDir = await getApplicationDocumentsDirectory();
        _customStickersDir = Directory(
          p.join(appDir.path, 'InkFlowData', 'stickers', 'custom'),
        );
        if (!await _customStickersDir!.exists()) {
          await _customStickersDir!.create(recursive: true);
        }
      }

      final destPath = p.join(
        _customStickersDir!.path,
        '${_uuid.v4()}_$fileName',
      );
      await sourceFile.copy(destPath);
      await refreshCustomStickers();

      return _customStickers.firstWhere((s) => s.filePath == destPath);
    } catch (e) {
      debugPrint('Error al importar imagen como sticker: $e');
      return null;
    }
  }

  /// Guarda una imagen o recorte en bytes (ej. PNG) como sticker propio del usuario
  Future<StickerItem?> saveBytesAsSticker(Uint8List bytes, String name) async {
    try {
      if (_customStickersDir == null) {
        final appDir = await getApplicationDocumentsDirectory();
        _customStickersDir = Directory(
          p.join(appDir.path, 'InkFlowData', 'stickers', 'custom'),
        );
        if (!await _customStickersDir!.exists()) {
          await _customStickersDir!.create(recursive: true);
        }
      }

      final cleanName = name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final destPath = p.join(
        _customStickersDir!.path,
        '${cleanName}_${_uuid.v4().substring(0, 8)}.png',
      );
      final file = File(destPath);
      await file.writeAsBytes(bytes);

      await refreshCustomStickers();
      return _customStickers.firstWhere((s) => s.filePath == destPath);
    } catch (e) {
      debugPrint('Error al guardar bytes como sticker: $e');
      return null;
    }
  }

  /// Importa un paquete de stickers comprimido en ZIP
  Future<int> importZipPack() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.single.path == null) return 0;

      final zipFile = File(result.files.single.path!);
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      if (_customStickersDir == null) {
        final appDir = await getApplicationDocumentsDirectory();
        _customStickersDir = Directory(
          p.join(appDir.path, 'InkFlowData', 'stickers', 'custom'),
        );
        if (!await _customStickersDir!.exists()) {
          await _customStickersDir!.create(recursive: true);
        }
      }

      int count = 0;
      for (final file in archive) {
        if (file.isFile) {
          final ext = p.extension(file.name).toLowerCase();
          if (['.png', '.jpg', '.jpeg', '.svg', '.webp'].contains(ext)) {
            final fileName = p.basename(file.name);
            final destPath = p.join(
              _customStickersDir!.path,
              '${_uuid.v4().substring(0, 8)}_$fileName',
            );
            final outFile = File(destPath);
            await outFile.writeAsBytes(file.content as List<int>);
            count++;
          }
        }
      }

      await refreshCustomStickers();
      return count;
    } catch (e) {
      debugPrint('Error al importar pack zip de stickers: $e');
      return 0;
    }
  }
}
