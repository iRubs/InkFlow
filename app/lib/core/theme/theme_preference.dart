import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'dart:io';

import '../storage/atomic_json_store.dart';

final themeModeProvider = StateNotifierProvider<ThemePreference, ThemeMode>(
  (ref) => ThemePreference(),
);

class ThemePreference extends StateNotifier<ThemeMode> {
  ThemePreference() : super(ThemeMode.system) {
    _load();
  }
  Future<File> _file() async => File(
    p.join(
      (await getApplicationDocumentsDirectory()).path,
      'InkFlowData',
      'settings.json',
    ),
  );
  Future<void> _load() async {
    try {
      final data = await AtomicJsonStore.read(await _file());
      if (mounted) {
        state = ThemeMode.values.firstWhere(
          (v) => v.name == data?['theme'],
          orElse: () => ThemeMode.system,
        );
      }
    } catch (error) {
      debugPrint('No se pudieron cargar las preferencias: $error');
    }
  }

  Future<void> select(ThemeMode mode) async {
    state = mode;
    await AtomicJsonStore.write(await _file(), {'theme': mode.name});
  }
}
