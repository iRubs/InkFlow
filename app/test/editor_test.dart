import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/data/database/app_database.dart';
import 'package:inkflow/features/editor/presentation/editor_screen.dart';
import 'package:inkflow/shared/providers/database_provider.dart';

void main() {
  group('Pruebas del Editor de Bloques (EditorScreen / AppFlowyEditor)', () {
    late AppDatabase testDb;

    setUp(() {
      testDb = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await testDb.close();
    });

    test('Serialización y deserialización de documento JSON estándar', () {
      // 1. Crear documento en blanco
      final editorState = EditorState.blank(withInitialText: true);
      expect(editorState.document.root.children.isNotEmpty, isTrue);

      // 2. Serializar a JSON
      final jsonMap = editorState.document.toJson();
      expect(jsonMap, isNotNull);
      expect(jsonMap.containsKey('document'), isTrue);

      final jsonString = jsonEncode(jsonMap);
      expect(jsonString.length, greaterThan(10));

      // 3. Deserializar desde JSON
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final restoredState = EditorState(document: Document.fromJson(decoded));
      expect(
        restoredState.document.root.children.length,
        equals(editorState.document.root.children.length),
      );
    });

    testWidgets('EditorScreen se inicializa y renderiza correctamente', (
      tester,
    ) async {
      final now = DateTime.now();
      final page = Page(
        id: 'test-editor-page-1',
        sectionId: 'test-section-1',
        title: 'Nota de Prueba Enriquecida',
        pageType: 'text',
        templateId: 'blank',
        paperColor: '#FFFFFF',
        orientation: 'portrait',
        paperSize: 'A4',
        isFavorite: false,
        isDeleted: false,
        deletedAt: null,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(testDb)],
          child: MaterialApp(
            localizationsDelegates: const [
              AppFlowyEditorLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: EditorScreen(
              page: page,
              initialEditorState: EditorState.blank(withInitialText: true),
            ),
          ),
        ),
      );

      await tester.pump();

      // Verificar que el título de la página aparece en el AppBar
      expect(find.text('Nota de Prueba Enriquecida'), findsOneWidget);

      // Verificar presencia de botones de Deshacer, Rehacer y Guardar
      expect(find.byIcon(Icons.undo_rounded), findsOneWidget);
      expect(find.byIcon(Icons.redo_rounded), findsOneWidget);
      expect(find.byIcon(Icons.save_outlined), findsOneWidget);

      // Verificar que AppFlowyEditor está montado en el árbol
      expect(find.byType(AppFlowyEditor), findsOneWidget);
    });
  });
}
