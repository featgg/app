import 'package:featgg/main.dart';
import 'package:featgg/src/core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('router', () {
    testWidgets('resolves the root route to the placeholder', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: App()));
      await tester.pumpAndSettle();
      expect(find.byType(RouterPlaceholderPage), findsOneWidget);
    });

    testWidgets('App applies AppTheme via MaterialApp.router', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: App()));
      await tester.pumpAndSettle();
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.theme?.useMaterial3, isTrue);
    });
  });
}
