import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../../data/database/app_database.dart';
import '../../features/library/services/page_deletion_service.dart';

/// Proveedor singleton de la base de datos local SQLite de InkFlow.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Stream reactivo de cuadernos activos
final activeNotebooksProvider = StreamProvider<List<Notebook>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchActiveNotebooks();
});

/// Stream reactivo de cuadernos favoritos
final favoriteNotebooksProvider = StreamProvider<List<Notebook>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchFavoriteNotebooks();
});

/// Stream reactivo de cuadernos eliminados (Papelera)
final trashNotebooksProvider = StreamProvider<List<Notebook>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchDeletedNotebooks();
});

/// ID del cuaderno actualmente abierto
final selectedNotebookIdProvider = StateProvider<String?>((ref) => null);

/// ID de la sección actualmente seleccionada
final selectedSectionIdProvider = StateProvider<String?>((ref) => null);

/// ID de la página actualmente en edición/visualización
final selectedPageIdProvider = StateProvider<String?>((ref) => null);

/// Modo actual de vista de la barra lateral (0 = Cuadernos, 1 = Favoritos, 2 = Papelera, 3 = Ajustes)
final navigationIndexProvider = StateProvider<int>((ref) => 0);

final allTagsProvider = StreamProvider<List<Tag>>(
  (ref) => ref.watch(databaseProvider).watchTags(),
);
final pageTagsProvider = StreamProvider.family<List<Tag>, String>(
  (ref, id) => ref.watch(databaseProvider).watchTagsForPage(id),
);

final pageDeletionServiceProvider = Provider<PageDeletionService>(
  (ref) => PageDeletionService(ref.watch(databaseProvider)),
);

/// Content files are already saved when this metadata-only update is called.
Future<void> recordPageEdit(WidgetRef ref, String pageId) async {
  try {
    await ref.read(databaseProvider).recordPageEdited(pageId);
  } catch (error) {
    debugPrint('No se pudo actualizar la actividad de la página: $error');
  }
}
