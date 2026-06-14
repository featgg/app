import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/connections_repository.dart';
import 'package:featgg/src/features/profile/domain/data_menu_catalog.dart';
import 'package:featgg/src/features/profile/domain/data_menu_selection.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_repository.dart';
import 'package:featgg/src/features/profile/presentation/data_menu_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Records the selection write so a toggle is observable.
final class _RecordingWidgetsRepository implements ProfileWidgetsRepository {
  DataMenuSelection? lastSelection;

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets() async =>
      right(const []);

  @override
  Future<Either<Failure, Unit>> setDataMenuSelection(
    String id,
    ProfileWidgetSize size,
    DataMenuSelection selection,
  ) async {
    lastSelection = selection;
    return right(unit);
  }

  @override
  Future<Either<Failure, ProfileWidget>> addPlatformWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> removeWidget(String id) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setSize(
    String id,
    ProfileWidgetSize size,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> reorder(List<String> orderedIds) async =>
      throw UnimplementedError();
}

final class _FakeConnectionsRepository implements ConnectionsRepository {
  _FakeConnectionsRepository(this.platforms);

  final List<Platform> platforms;

  @override
  Future<Either<Failure, List<Connection>>> fetchMyConnections() async =>
      right([
        for (final p in platforms)
          Connection(
            platform: p,
            status: ConnectionStatus.active,
            createdAt: DateTime.utc(2026, 1, 1),
          ),
      ]);

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

  @override
  Future<Either<Failure, RefreshAllResult>> refreshAll() async =>
      right(const RefreshAllResult(outcomes: []));
}

ProfileWidget _widget() => const ProfileWidget(
  id: 'w-1',
  kind: ProfileWidgetKind.platform,
  platform: Platform.steam,
  position: 0,
  isEnabled: true,
  size: ProfileWidgetSize.small,
);

Widget _harness({
  required List<Platform> connected,
  required ProfileWidgetsRepository widgetsRepo,
  ProfileWidget? widget,
}) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      connectionsRepositoryProvider.overrideWithValue(
        _FakeConnectionsRepository(connected),
      ),
      profileWidgetsRepositoryProvider.overrideWithValue(widgetsRepo),
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
      home: Scaffold(body: DataMenuSheet(widget: widget ?? _widget())),
    ),
  );
}

void main() {
  testWidgets('renders the five category sections that have connected items', (
    tester,
  ) async {
    // Connect every catalog platform so all five categories have items.
    await tester.pumpWidget(
      _harness(
        connected: Platform.values,
        widgetsRepo: _RecordingWidgetsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    for (final category in DataMenuCategory.values) {
      expect(
        find.byKey(Key('dataMenuCategory_${category.name}')),
        findsOneWidget,
        reason: category.name,
      );
    }
  });

  testWidgets('shows only connected platforms\' items', (tester) async {
    // Only Steam connected: a Steam item is shown, a chess item is not.
    await tester.pumpWidget(
      _harness(
        connected: const [Platform.steam],
        widgetsRepo: _RecordingWidgetsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('dataMenuItem_steam.hours_played')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('dataMenuItem_chess.rating')), findsNothing);
  });

  testWidgets('the platform filter narrows the visible items', (tester) async {
    await tester.pumpWidget(
      _harness(
        connected: const [Platform.steam, Platform.chess],
        widgetsRepo: _RecordingWidgetsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    // Both visible under "All".
    expect(
      find.byKey(const Key('dataMenuItem_steam.hours_played')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('dataMenuItem_chess.rating')), findsOneWidget);

    // Filter to chess: the steam item drops out.
    await tester.tap(find.byKey(const Key('dataMenuFilter_chess')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('dataMenuItem_steam.hours_played')),
      findsNothing,
    );
    expect(find.byKey(const Key('dataMenuItem_chess.rating')), findsOneWidget);
  });

  testWidgets(
    'toggling an item persists the selection through the controller',
    (tester) async {
      final repo = _RecordingWidgetsRepository();
      await tester.pumpWidget(
        _harness(connected: const [Platform.steam], widgetsRepo: repo),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('dataMenuItem_steam.hours_played')),
      );
      await tester.pumpAndSettle();

      expect(repo.lastSelection, isNotNull);
      expect(repo.lastSelection!.selectedIds, contains('steam.hours_played'));
    },
  );

  testWidgets('with no connections, shows the connect-first hint', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(connected: const [], widgetsRepo: _RecordingWidgetsRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dataMenuConnectFirst')), findsOneWidget);
  });
}
