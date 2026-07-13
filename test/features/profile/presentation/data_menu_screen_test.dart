import 'dart:async';

import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/connections_repository.dart';
import 'package:featgg/src/features/profile/domain/collection_selection.dart';
import 'package:featgg/src/features/profile/domain/composed_card.dart';
import 'package:featgg/src/features/profile/domain/data_menu_catalog.dart';
import 'package:featgg/src/features/profile/domain/data_menu_selection.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_repository.dart';
import 'package:featgg/src/features/profile/domain/showcase_selection.dart';
import 'package:featgg/src/features/profile/domain/template_catalog.dart';
import 'package:featgg/src/features/profile/presentation/data_menu_screen.dart';
import 'package:featgg/src/features/profile/presentation/profile_widgets_provider.dart';
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
  Future<Either<Failure, List<ProfileWidget>>> fetchPublicWidgets(
    String userId,
  ) async => right(const []);

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
  Future<Either<Failure, ProfileWidget>> addTemplateWidget({
    required String templateId,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setTemplateFill(
    String id,
    ProfileWidgetSize size,
    TemplateFill fill,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addComposedWidget({
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addShowcaseWidget({
    required Platform platform,
    required ShowcaseSelection selection,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addCollectionWidget({
    required CollectionSelection selection,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addGameCollectorWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addCompletionistWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addPassportWidget({
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setCollectionSize(
    String id,
    ProfileWidgetSize size,
    CollectionSelection selection,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setComposedFill(
    String id,
    ProfileWidgetSize size,
    ComposedFill fill,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> removeWidget(String id) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setSize(
    String id,
    ProfileWidgetSize size,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setShowcaseSize(
    String id,
    ProfileWidgetSize size,
    ShowcaseSelection selection,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> reorder(List<String> orderedIds) async =>
      throw UnimplementedError();
}

/// A widgets repository whose `setDataMenuSelection` fails, and whose
/// `fetchMyWidgets` counts its calls so the invalidate-driven refresh is
/// observable.
final class _ConfigurableWidgetsRepository implements ProfileWidgetsRepository {
  _ConfigurableWidgetsRepository({this.failure});

  /// When non-null, every selection write returns this failure.
  final Failure? failure;

  int fetchCalls = 0;
  final List<DataMenuSelection> writes = [];

  /// When set, a selection write does not complete until this completes.
  Completer<void>? gate;

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets() async {
    fetchCalls++;
    return right(const []);
  }

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchPublicWidgets(
    String userId,
  ) async => right(const []);

  @override
  Future<Either<Failure, Unit>> setDataMenuSelection(
    String id,
    ProfileWidgetSize size,
    DataMenuSelection selection,
  ) async {
    writes.add(selection);
    if (gate != null) await gate!.future;
    final f = failure;
    return f != null ? left(f) : right(unit);
  }

  @override
  Future<Either<Failure, ProfileWidget>> addPlatformWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addTemplateWidget({
    required String templateId,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setTemplateFill(
    String id,
    ProfileWidgetSize size,
    TemplateFill fill,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addComposedWidget({
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addShowcaseWidget({
    required Platform platform,
    required ShowcaseSelection selection,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addCollectionWidget({
    required CollectionSelection selection,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addGameCollectorWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addCompletionistWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addPassportWidget({
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setCollectionSize(
    String id,
    ProfileWidgetSize size,
    CollectionSelection selection,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setComposedFill(
    String id,
    ProfileWidgetSize size,
    ComposedFill fill,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> removeWidget(String id) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setSize(
    String id,
    ProfileWidgetSize size,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setShowcaseSize(
    String id,
    ProfileWidgetSize size,
    ShowcaseSelection selection,
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

/// Builds the container directly so a test can read `ownerProfileWidgetsProvider`
/// (to assert the post-save refresh) or hold the gate that overlaps two writes.
ProviderContainer _container({
  required List<Platform> connected,
  required ProfileWidgetsRepository widgetsRepo,
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
  return container;
}

Widget _app(ProviderContainer container, {ProfileWidget? widget}) =>
    UncontrolledProviderScope(
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

  testWidgets('a failed save surfaces the error SnackBar (not swallowed)', (
    tester,
  ) async {
    // Without the sheet observing the controller, the autoDispose controller
    // disposes after the sync call and the Left never reaches the UI.
    final repo = _ConfigurableWidgetsRepository(
      failure: const NetworkFailure(),
    );
    await tester.pumpWidget(
      _app(_container(connected: const [Platform.steam], widgetsRepo: repo)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dataMenuItem_steam.hours_played')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dataMenuErrorSnackBar')), findsOneWidget);
  });

  testWidgets('a successful save refreshes the read (invalidate fires)', (
    tester,
  ) async {
    // The controller invalidates ownerProfileWidgetsProvider on success, which
    // only fires if the sheet keeps the autoDispose controller alive across the
    // write. fetchCalls increasing proves the refresh happened.
    final repo = _ConfigurableWidgetsRepository();
    final container = _container(
      connected: const [Platform.steam],
      widgetsRepo: repo,
    );
    container.listen(ownerProfileWidgetsProvider, (_, _) {});
    await container.read(ownerProfileWidgetsProvider.future);
    final fetchesBefore = repo.fetchCalls;

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dataMenuItem_steam.hours_played')));
    await tester.pumpAndSettle();

    expect(repo.fetchCalls, greaterThan(fetchesBefore));
  });

  testWidgets('toggles are disabled while a save is in flight (no stale write)', (
    tester,
  ) async {
    // The first write is held open by the gate so it stays in flight; a second
    // toggle must be suppressed (onChanged == null) and issue no second write.
    final repo = _ConfigurableWidgetsRepository()..gate = Completer<void>();
    await tester.pumpWidget(
      _app(_container(connected: const [Platform.steam], widgetsRepo: repo)),
    );
    await tester.pumpAndSettle();

    // Start write 1.
    await tester.tap(find.byKey(const Key('dataMenuItem_steam.hours_played')));
    await tester.pump();

    // A different connected item's tile is disabled while the save is in flight.
    final otherTile = tester.widget<SwitchListTile>(
      find.byKey(const Key('dataMenuItem_steam.library_showcase')),
    );
    expect(otherTile.onChanged, isNull);

    // Tapping the disabled tile is a no-op: still exactly one write recorded.
    await tester.tap(
      find.byKey(const Key('dataMenuItem_steam.library_showcase')),
    );
    await tester.pump();
    expect(repo.writes, hasLength(1));

    // Release write 1; the single recorded write carries the first selection.
    repo.gate!.complete();
    await tester.pumpAndSettle();

    expect(repo.writes, hasLength(1));
    expect(repo.writes.single.selectedIds, contains('steam.hours_played'));
  });
}
