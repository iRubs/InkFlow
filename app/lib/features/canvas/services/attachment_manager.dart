import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Gestor de adjuntos locales (imágenes, PDFs y exportaciones).
///
/// Garantiza persistencia 100% offline dentro del directorio seguro de la app.
class AttachmentManager {
  static const _uuid = Uuid();
  Directory? _baseDir;
  Directory? _imagesDir;
  Directory? _pdfsDir;
  Directory? _exportsDir;

  bool _initialized = false;

  Future<void> init({Directory? baseDirectory}) async {
    if (_initialized) return;

    try {
      final docs = baseDirectory ?? await getApplicationDocumentsDirectory();
      _baseDir = Directory(p.join(docs.path, 'InkFlowData', 'attachments'));
      _imagesDir = Directory(p.join(_baseDir!.path, 'images'));
      _pdfsDir = Directory(p.join(_baseDir!.path, 'pdfs'));
      _exportsDir = Directory(p.join(_baseDir!.path, 'exports'));

      if (!await _imagesDir!.exists()) {
        await _imagesDir!.create(recursive: true);
      }
      if (!await _pdfsDir!.exists()) {
        await _pdfsDir!.create(recursive: true);
      }
      if (!await _exportsDir!.exists()) {
        await _exportsDir!.create(recursive: true);
      }

      _initialized = true;
    } catch (e) {
      debugPrint('Error al inicializar AttachmentManager: $e');
    }
  }

  /// Accepts document-provider bytes as well as ordinary files. Decode before
  /// saving, preserve aspect ratio, and bound the working bitmap on tablets.
  Future<({String path, int width, int height})> importImageBytes(
    Uint8List bytes, {
    Directory? baseDirectory,
  }) async {
    if (bytes.isEmpty || bytes.length > 40 * 1024 * 1024) {
      throw const FormatException(
        'La imagen debe ocupar entre 1 byte y 40 MB.',
      );
    }
    await init(baseDirectory: baseDirectory);
    if (!_initialized) {
      throw const FileSystemException(
        'No se pudo abrir la carpeta de imágenes.',
      );
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final ratio = math.min(
        1.0,
        2048 / math.max(descriptor.width, descriptor.height),
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * ratio).round()),
        targetHeight: math.max(1, (descriptor.height * ratio).round()),
      );
      image = (await codec.getNextFrame()).image;
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) {
        throw const FormatException('Formato de imagen no compatible.');
      }
      final target = File(p.join(_imagesDir!.path, '${_uuid.v4()}.png'));
      await target.writeAsBytes(
        png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
        flush: true,
      );
      return (path: target.path, width: image.width, height: image.height);
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  /// Copia una imagen seleccionada a la carpeta local de adjuntos y devuelve la nueva ruta
  Future<String?> saveImageAttachment(String sourceFilePath) async {
    await init();
    try {
      final source = File(sourceFilePath);
      if (!await source.exists()) return null;

      final extension = p.extension(sourceFilePath);
      final filename = '${_uuid.v4()}$extension';
      final target = File(p.join(_imagesDir!.path, filename));

      await source.copy(target.path);
      return target.path;
    } catch (e) {
      debugPrint('Error al guardar imagen adjunta: $e');
      return null;
    }
  }

  /// Copia un documento PDF al almacenamiento de InkFlow asociado a una página
  Future<String?> savePdfAttachment(
    String pageId,
    String sourceFilePath,
  ) async {
    await init();
    try {
      final source = File(sourceFilePath);
      if (!await source.exists()) return null;

      final target = File(p.join(_pdfsDir!.path, '$pageId.pdf'));
      await source.copy(target.path);
      return target.path;
    } catch (e) {
      debugPrint('Error al guardar PDF adjunto: $e');
      return null;
    }
  }

  /// Obtiene el archivo PDF asociado al pageId, si existe
  Future<File?> getPdfFile(String pageId) async {
    await init();
    final file = File(p.join(_pdfsDir!.path, '$pageId.pdf'));
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  /// Retorna la ruta del directorio de exportaciones
  Future<Directory> getExportsDirectory() async {
    await init();
    return _exportsDir!;
  }
}
