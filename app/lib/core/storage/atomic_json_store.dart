import 'dart:convert';
import 'dart:io';

/// Conserva la última versión válida y serializa escrituras por archivo.
/// Un cierre entre renombrados se recupera desde .previous o .pending.
class AtomicJsonStore {
  static final Map<String, Future<void>> _writes = {};

  static Future<void> write(File file, Map<String, dynamic> data) {
    final snapshot = jsonEncode(data);
    final key = file.absolute.path;
    final previous = _writes[key] ?? Future<void>.value();
    final next = previous.catchError((Object _) {}).then((_) async {
      await file.parent.create(recursive: true);
      final pending = File('${file.path}.pending');
      final backup = File('${file.path}.previous');
      await pending.writeAsString(snapshot, flush: true);
      if (await file.exists()) {
        if (await backup.exists()) await backup.delete();
        await file.rename(backup.path);
      }
      await pending.rename(file.path);
    });
    _writes[key] = next;
    // La cola no debe retener rutas de todos los documentos abiertos.
    next.then(
      (_) {
        if (identical(_writes[key], next)) _writes.remove(key);
      },
      onError: (Object _, StackTrace __) {
        if (identical(_writes[key], next)) _writes.remove(key);
      },
    );
    return next;
  }

  static Future<void> flush() async {
    while (_writes.isNotEmpty) {
      await Future.wait(_writes.values.toList());
    }
  }

  static Future<Map<String, dynamic>?> read(File file) async {
    final queued = _writes[file.absolute.path];
    if (queued != null) await queued;
    var found = false;
    for (final candidate in [
      file,
      File('${file.path}.pending'),
      File('${file.path}.previous'),
    ]) {
      if (!await candidate.exists()) continue;
      found = true;
      try {
        return jsonDecode(await candidate.readAsString())
            as Map<String, dynamic>;
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    if (found) {
      throw const FormatException(
        'No se encontró una versión válida del documento.',
      );
    }
    return null;
  }
}
