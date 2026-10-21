import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/backup/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BackupService backupService;
  late Directory tempDir;

  setUp(() async {
    backupService = BackupService();
    tempDir = await Directory.systemTemp.createTemp('inkflow_backup_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Pruebas del Motor de Respaldo y Restauración (BackupService)', () {
    test('Empaquetado de respaldo genera archivo ZIP con inkflow_manifest.json válido', () async {
      final zipPath = '${tempDir.path}/backup_test.inkflow';

      final zipFile = await backupService.createBackup(
        destinationZipPath: zipPath,
        customDataDir: tempDir,
      );

      expect(await zipFile.exists(), isTrue);
      final bytes = await zipFile.readAsBytes();
      expect(bytes.length, greaterThan(20));

      final archive = ZipDecoder().decodeBytes(bytes);
      final manifestFile = archive.findFile('inkflow_manifest.json');
      expect(manifestFile, isNotNull);

      final manifestJson = jsonDecode(
        utf8.decode(manifestFile!.content as List<int>),
      ) as Map<String, dynamic>;

      expect(manifestJson['app'], equals('InkFlow'));
      expect(manifestJson['version'], equals('1.2.0'));
      expect(manifestJson['schemaVersion'], equals(1));
    });

    test(
      'Validación de rechazo de archivos corruptos o sin manifiesto',
      () async {
        final invalidZipPath = '${tempDir.path}/corrupt.inkflow';
        final archive = Archive();
        archive.addFile(ArchiveFile('random.txt', 4, utf8.encode('test')));
        final zipBytes = ZipEncoder().encode(archive);
        final invalidFile = File(invalidZipPath);
        await invalidFile.writeAsBytes(zipBytes);

        final success = await backupService.restoreBackup(
          backupZipPath: invalidZipPath,
        );

        expect(success, isFalse);
      },
    );
  });
}
