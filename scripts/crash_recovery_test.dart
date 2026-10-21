import 'dart:async';
import 'dart:io';

import '../app/lib/core/storage/atomic_json_store.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.isNotEmpty) {
    final file = File(arguments.single);
    for (var revision = 0; ; revision++) {
      await AtomicJsonStore.write(file, {
        'revision': revision,
        'strokes': List.generate(
          5000,
          (i) => {
            'id': i,
            'points': List.filled(20, {'x': 1, 'y': 2, 'p': 0.7}),
          },
        ),
      });
      stdout.writeln('COMMITTED $revision');
    }
  }
  final directory = await Directory.systemTemp.createTemp(
    'inkflow_force_close_',
  );
  try {
    final file = File('${directory.path}/note.json');
    final process = await Process.start(Platform.resolvedExecutable, [
      Platform.script.toFilePath(),
      file.path,
    ]);
    final committed = Completer<void>();
    process.stdout.listen((bytes) {
      if (!committed.isCompleted) committed.complete();
    });
    final errors = <int>[];
    process.stderr.listen(errors.addAll);
    await committed.future.timeout(const Duration(seconds: 30));
    await Future<void>.delayed(const Duration(milliseconds: 25));
    process.kill();
    await process.exitCode;
    final restored = await AtomicJsonStore.read(file);
    if (restored == null || (restored['strokes'] as List).length != 5000)
      throw StateError('Fallo la recuperacion tras terminacion del proceso.');
    stdout.writeln(
      'PASS: proceso terminado durante guardado continuo; revision recuperada ${restored['revision']}, 5000 trazos completos.',
    );
  } finally {
    for (var attempt = 0; ; attempt++) {
      try {
        await directory.delete(recursive: true);
        break;
      } on FileSystemException {
        if (attempt == 9) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  }
}
