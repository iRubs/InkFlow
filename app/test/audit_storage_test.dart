import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/core/storage/atomic_json_store.dart';
import 'package:inkflow/data/database/app_database.dart';
import 'package:inkflow/features/backup/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('inkflow_audit_');
  });
  tearDown(() async {
    await AtomicJsonStore.flush();
    await temp.delete(recursive: true);
  });

  test(
    '30 escrituras concurrentes conservan la última revisión y JSON válido',
    () async {
      final file = File('${temp.path}/note.json');
      await Future.wait(
        List.generate(30, (i) => AtomicJsonStore.write(file, {'revision': i})),
      );
      expect((await AtomicJsonStore.read(file))!['revision'], 29);
      expect(await File('${file.path}.previous').exists(), isTrue);
    },
  );
  test('Recupera la revisión anterior tras truncamiento y cierre entre renombrados', () async {
    final file = File('${temp.path}/note.json');
    await AtomicJsonStore.write(file, {'revision': 1});
    await AtomicJsonStore.write(file, {'revision': 2});
    await file.writeAsString('{truncado');
    expect((await AtomicJsonStore.read(file))!['revision'], 1);
    await file.delete();
    await File('${file.path}.pending').writeAsString('{"revision":3}');
    expect((await AtomicJsonStore.read(file))!['revision'], 3);
  });
  test('No convierte un documento corrupto en una página vacía', () async {
    final file = File('${temp.path}/broken.json');
    await file.writeAsString('broken');
    await expectLater(AtomicJsonStore.read(file), throwsFormatException);
    expect(await file.readAsString(), 'broken');
  });
  test('Guarda y recupera 1500 trazos sin perder presión ni puntos', () async {
    final data = {
      'strokes': List.generate(
        1500,
        (i) => {
          'id': '$i',
          'points': List.generate(
            20,
            (j) => {'x': i + j, 'y': j, 'pressure': 0.75},
          ),
        },
      ),
    };
    final file = File('${temp.path}/large.json');
    final timer = Stopwatch()..start();
    await AtomicJsonStore.write(file, data);
    final restored = await AtomicJsonStore.read(file);
    expect(restored!['strokes'], data['strokes']);
    // Medición informativa: no confundir almacenamiento con fps de un S Pen real.
    // ignore: avoid_print
    print('1500 trazos: guardado + lectura ${timer.elapsedMilliseconds} ms');
  });
  test(
    'SQLite activa cascadas y la búsqueda excluye cuadernos en papelera',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.insertNotebook(
        NotebooksCompanion.insert(id: 'n', title: 'Cuaderno'),
      );
      await db.insertSection(
        SectionsCompanion.insert(id: 's', notebookId: 'n', title: 'Sección'),
      );
      await db.insertPage(
        PagesCompanion.insert(id: 'p', sectionId: 's', title: 'Buscar aquí'),
      );
      expect(await db.searchPages('Buscar').first, hasLength(1));
      await db.softDeleteNotebook('n');
      expect(await db.searchPages('Buscar').first, isEmpty);
      await db.permanentDeleteNotebook('n');
      expect(await db.getPageById('p'), isNull);
      expect(await db.select(db.sections).get(), isEmpty);
    },
  );
  test('Respaldo restaura SQLite real, archivos y rutas en otro dispositivo', () async {
    final source = Directory('${temp.path}/source')..createSync();
    final target = Directory('${temp.path}/target')..createSync();
    final image = File('${source.path}/attachments/image.png');
    await image.parent.create(recursive: true);
    await image.writeAsBytes([1, 2, 3]);
    await AtomicJsonStore.write(File('${source.path}/strokes/page.json'), {
      'images': [
        {'filePath': image.path},
      ],
    });
    final db = AppDatabase(NativeDatabase.memory());
    await db.insertNotebook(
      NotebooksCompanion.insert(id: 'n', title: 'Respaldo íntegro'),
    );
    final backup = await BackupService(database: db).createBackup(
      destinationZipPath: '${temp.path}/backup.inkflow',
      customDataDir: source,
    );
    await db.close();
    await File('${target.path}/stale.txt').writeAsString('anterior');
    expect(
      await BackupService().restoreBackup(
        backupZipPath: backup.path,
        customDataDir: target,
      ),
      isTrue,
    );
    final restored = AppDatabase(
      NativeDatabase(File('${target.path}/inkflow.sqlite')),
    );
    expect((await restored.getNotebookById('n'))!.title, 'Respaldo íntegro');
    await restored.close();
    final json = await AtomicJsonStore.read(
      File('${target.path}/strokes/page.json'),
    );
    expect(
      (json!['images'] as List).first['filePath'],
      '${target.path}${Platform.pathSeparator}attachments${Platform.pathSeparator}image.png',
    );
    expect(await File('${target.path}/stale.txt').exists(), isFalse);
    expect(
      temp.listSync().whereType<Directory>().any(
        (dir) => dir.path.contains('.before-restore-'),
      ),
      isTrue,
    );
  });

  Future<File> malicious(String name, {bool badHash = false}) async {
    final bytes = utf8.encode('contenido');
    final manifest = utf8.encode(
      jsonEncode({
        'app': 'InkFlow',
        'backupVersion': 2,
        'schemaVersion': 1,
        'filesCount': 1,
        'files': {name: badHash ? 'bad' : sha256.convert(bytes).toString()},
      }),
    );
    final archive = Archive()
      ..addFile(ArchiveFile(name, bytes.length, bytes))
      ..addFile(
        ArchiveFile('inkflow_manifest.json', manifest.length, manifest),
      );
    return File('${temp.path}/bad.inkflow')
        .writeAsBytes(ZipEncoder().encode(archive));
  }

  for (final name in [
    '../escape.txt',
    r'..\escape.txt',
    '/absolute.txt',
    'C:/outside.txt',
    'valid/../../escape.txt',
  ]) {
    test(
      'Rechaza ruta de ZIP $name sin modificar los datos existentes',
      () async {
        final target = Directory('${temp.path}/target')..createSync();
        final existing = File('${target.path}/keep.txt')
          ..writeAsStringSync('conservar');
        final file = await malicious(name);
        expect(
          await BackupService().restoreBackup(
            backupZipPath: file.path,
            customDataDir: target,
          ),
          isFalse,
        );
        expect(await existing.readAsString(), 'conservar');
      },
    );
  }
  test('Rechaza hash inválido antes de tocar la carpeta de destino', () async {
    final file = await malicious('safe.txt', badHash: true);
    final target = Directory('${temp.path}/target');
    expect(
      await BackupService().restoreBackup(
        backupZipPath: file.path,
        customDataDir: target,
      ),
      isFalse,
    );
    expect(await target.exists(), isFalse);
  });
}
