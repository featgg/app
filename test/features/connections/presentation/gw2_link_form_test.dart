import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/connections_repository.dart';
import 'package:featgg/src/features/connections/presentation/gw2_link_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

final class _FakeConnectionsRepository implements ConnectionsRepository {
  @override
  Future<Either<Failure, List<Connection>>> fetchMyConnections() async =>
      right([]);

  @override
  Future<Either<Failure, Unit>> link({
    required Platform platform,
    required Map<String, String> formInput,
  }) async => right(unit);

  @override
  Future<Either<Failure, Unit>> unlink(Platform platform) async => right(unit);

  @override
  Future<Either<Failure, SyncResult>> refresh(Platform platform) async =>
      right(const SyncResult(skipped: false));
}

Widget _wrap(Widget child) {
  // Override at a root ProviderContainer (via UncontrolledProviderScope) rather
  // than a ProviderScope widget: riverpod_lint treats a widget-test ProviderScope
  // as a non-root scope and misfires scoped_providers_should_specify_dependencies
  // when the overridden seam is read by a family provider. A root container is
  // unambiguously root, so the override is correct and lint-clean.
  final container = ProviderContainer(
    overrides: [
      connectionsRepositoryProvider.overrideWithValue(
        _FakeConnectionsRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('Gw2LinkForm', () {
    testWidgets(
      'GW2 api-key field is obscured with autocorrect and suggestions disabled',
      (tester) async {
        await tester.pumpWidget(_wrap(const Gw2LinkForm()));
        await tester.pump();

        final field = tester.widget<TextField>(
          find.byKey(const Key('gw2ApiKeyField')),
        );

        expect(field.obscureText, isTrue);
        expect(field.autocorrect, isFalse);
        expect(field.enableSuggestions, isFalse);
      },
    );

    testWidgets('visibility toggle reveals and re-obscures the api-key field', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const Gw2LinkForm()));
      await tester.pump();

      bool obscured() => tester
          .widget<TextField>(find.byKey(const Key('gw2ApiKeyField')))
          .obscureText;
      final toggle = find.byKey(const Key('gw2ApiKeyVisibilityToggle'));

      expect(obscured(), isTrue);

      await tester.tap(toggle);
      await tester.pump();
      expect(obscured(), isFalse);

      await tester.tap(toggle);
      await tester.pump();
      expect(obscured(), isTrue);
    });
  });
}
