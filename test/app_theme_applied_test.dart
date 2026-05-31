import 'package:featgg/main.dart';
import 'package:featgg/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('App', () {
    testWidgets('applies the token-derived theme', (tester) async {
      // Pump App directly inside ProviderScope. bootstrap() is intentionally
      // not called — it would throw because no --dart-define-from-file is
      // present in the test environment.
      await tester.pumpWidget(const ProviderScope(child: App()));

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));

      expect(materialApp.theme, isNotNull);
      expect(materialApp.theme!.useMaterial3, isTrue);

      final expectedPrimary = ColorScheme.fromSeed(
        seedColor: AppColorTokens.seed,
      ).primary;
      expect(materialApp.theme!.colorScheme.primary, equals(expectedPrimary));
    });
  });
}
