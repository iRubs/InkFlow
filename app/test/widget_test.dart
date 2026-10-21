import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:inkflow/features/library/services/page_deletion_service.dart';
import 'package:inkflow/data/database/app_database.dart';
import 'package:inkflow/main.dart';
import 'package:inkflow/shared/providers/database_provider.dart';

class NoPendingDeletions extends PageDeletionService {
  NoPendingDeletions(super.database);
  @override
  Future<void> recoverPendingDeletions() async {}
}

void main() {
  testWidgets('InkFlow app initializes and renders home screen with database', (
    WidgetTester tester,
  ) async {
    final testDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          pageDeletionServiceProvider.overrideWithValue(
            NoPendingDeletions(testDb),
          ),
        ],
        child: const InkFlowApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verifica que el encabezado principal y el botón de crear cuaderno se muestren
    expect(find.text('Mis Cuadernos'), findsOneWidget);
    expect(find.text('Nuevo Cuaderno'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await testDb.close();
  });
}
