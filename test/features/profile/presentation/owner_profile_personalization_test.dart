import 'dart:async';

import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/connections_repository.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/profile.dart';
import 'package:featgg/src/features/profile/domain/profile_layout.dart';
import 'package:featgg/src/features/profile/domain/profile_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_repository.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_repository.dart';
import 'package:featgg/src/features/profile/presentation/personalization_archetype_cards.dart';
import 'package:featgg/src/features/profile/presentation/profile_composition_controller.dart';
import 'package:featgg/src/features/profile/presentation/profile_screen.dart';
import 'package:featgg/src/features/profile/presentation/profile_widgets_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

// A full-only card ('idc' → identity) and a dual-size card ('card' → fallback).
const _profile = Profile(
  id: 'owner-1',
  username: 'nico',
  displayName: 'Nico',
  avatarUrl: null,
  bio: null,
  theme: ProfileTheme.crimson,
  privacy: ProfilePrivacy.public,
  featuredPlatform: null,
  layout: [FullRow('idc'), FullRow('card')],
);

ProfileWidget _widget(String id, ProfileWidgetKind kind) => ProfileWidget(
  id: id,
  kind: kind,
  platform: null,
  position: 0,
  isEnabled: true,
);

final _widgets = [
  _widget('idc', ProfileWidgetKind.passport), // identity → full only
  _widget('card', ProfileWidgetKind.art), // fallback → both sizes
];

final class _FakeProfileRepo implements ProfileRepository {
  _FakeProfileRepo({this.setResult, this.profile = _profile});

  final Either<Failure, Unit> Function()? setResult;
  final Profile profile;

  @override
  Future<Either<Failure, Unit>> setMyLayout(
    List<ProfileLayoutRow> rows,
  ) async => setResult?.call() ?? right(unit);

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() async => right(profile);

  @override
  Future<Either<Failure, Profile>> updateMyProfile(ProfileEdit edit) async =>
      right(_profile);

  @override
  Future<Either<Failure, Profile?>> fetchPublicProfile(String userId) async =>
      right(null);
}

final class _FakeWidgetsRepo implements ProfileWidgetsRepository {
  _FakeWidgetsRepo(this.widgets);

  final List<ProfileWidget> widgets;

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets() async =>
      right(widgets);

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchPublicWidgets(
    String userId,
  ) async => right(widgets);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// A widgets repository whose `removeWidget` genuinely prunes its backing list,
/// so a re-fetch after a delete returns the reduced set — the exact behavior the
/// no-bounce-back delete relies on. Records the ids it was asked to remove.
final class _DeletableWidgetsRepo implements ProfileWidgetsRepository {
  _DeletableWidgetsRepo(this._widgets);

  final List<ProfileWidget> _widgets;
  final removed = <String>[];

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets() async =>
      right(List.of(_widgets));

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchPublicWidgets(
    String userId,
  ) async => right(List.of(_widgets));

  @override
  Future<Either<Failure, Unit>> removeWidget(String id) async {
    removed.add(id);
    _widgets.removeWhere((w) => w.id == id);
    return right(unit);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// A widgets repository whose Main write is deliberately asynchronous: it does
/// not commit (and does not return) until [gate] completes, or after [delay]. It
/// only grows its set on success, so a fresh read taken BEFORE the write commits
/// sees the stale list — the exact race the await-before-pop fix must close.
final class _AcquireWidgetsRepo implements ProfileWidgetsRepository {
  _AcquireWidgetsRepo(
    this._widgets, {
    this.delay = Duration.zero,
    this.gate,
    this.writeFailure,
  });

  final List<ProfileWidget> _widgets;
  final Duration delay;
  final Completer<void>? gate;
  final Failure? writeFailure;

  int addMainCalls = 0;

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets() async =>
      right(List.of(_widgets));

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchPublicWidgets(
    String userId,
  ) async => right(List.of(_widgets));

  @override
  Future<Either<Failure, ProfileWidget>> addMainWidget({
    required Platform platform,
    required int position,
  }) async {
    addMainCalls++;
    if (gate != null) {
      await gate!.future;
    } else {
      await Future<void>.delayed(delay);
    }
    if (writeFailure != null) return left(writeFailure!);
    final widget = ProfileWidget(
      id: 'mn',
      kind: ProfileWidgetKind.main,
      platform: platform,
      position: position,
      isEnabled: true,
    );
    _widgets.add(widget);
    return right(widget);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Counts pops so a test can assert an errant, extra route pop (e.g. a delayed
/// row pop landing on the screen beneath a sheet that closed by another channel).
final class _PopCountingObserver extends NavigatorObserver {
  int pops = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => pops++;
}

final class _FakeCardsRepo implements CardsRepository {
  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) async =>
      right(null);

  @override
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  ) async => right(null);
}

/// Reports Chess linked so the add-card catalog offers the Chess Rank/Main rows
/// the acquire-race guardrail drives (the catalog reads connected platforms).
final class _FakeConnectionsRepo implements ConnectionsRepository {
  @override
  Future<Either<Failure, List<Connection>>> fetchMyConnections() async =>
      right([
        Connection(
          platform: Platform.chess,
          status: ConnectionStatus.active,
          createdAt: DateTime.utc(2024),
        ),
      ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Serves a Chess card (which carries Main data) for Chess, nothing elsewhere,
/// so the acquisition section offers exactly the Chess Main/Rank rows.
final class _ChessCardsRepo implements CardsRepository {
  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) async =>
      right(platform == Platform.chess ? _chessCard() : null);

  @override
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  ) async => right(null);
}

GameCard _chessCard() => GameCard(
  schemaVersion: 1,
  platform: Platform.chess,
  title: 'chess',
  subtitle: null,
  iconImage: null,
  heroImage: null,
  profileUrl: null,
  stats: const [],
  lastUpdated: DateTime.utc(2026, 6, 1),
  data: const ChessCardData(
    primaryMode: 'RAPID',
    ratings: {'rapid': ChessModeRating(current: 1500, best: 1600)},
  ),
);

({Widget widget, ProviderContainer container}) _harness({
  Either<Failure, Unit> Function()? setResult,
}) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      profileRepositoryProvider.overrideWithValue(
        _FakeProfileRepo(setResult: setResult),
      ),
      profileWidgetsRepositoryProvider.overrideWithValue(
        _FakeWidgetsRepo(_widgets),
      ),
      cardsRepositoryProvider.overrideWithValue(_FakeCardsRepo()),
      connectionsRepositoryProvider.overrideWithValue(_FakeConnectionsRepo()),
    ],
  );
  addTearDown(container.dispose);
  final widget = UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // The compose controls now live in ProfileScreen's app bar, so the harness
      // mounts the real screen; the composed `_profile` routes to the surface.
      home: const ProfileScreen(),
    ),
  );
  return (widget: widget, container: container);
}

/// Pumps in a tall viewport so both composed rows sit on-screen and their
/// in-card handles/toggles are hittable (the default 800×600 view scrolls the
/// second card out of reach).
Future<void> _pump(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(700, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

Future<void> _enterEdit(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('profileEditButton')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('edit mode shows a handle per card and a size toggle only on '
      'dual-size cards', (tester) async {
    await _pump(tester, _harness().widget);

    await _enterEdit(tester);

    // Every card gets a drag handle.
    expect(find.byKey(const Key('compositionDragHandle_idc')), findsOneWidget);
    expect(find.byKey(const Key('compositionDragHandle_card')), findsOneWidget);

    // The size toggle appears only on the dual-size card, never on the
    // full-only identity card.
    expect(find.byKey(const Key('compositionSizeToggle_card')), findsOneWidget);
    expect(find.byKey(const Key('compositionSizeToggle_idc')), findsNothing);
  });

  testWidgets('Done is gated on dirty state', (tester) async {
    await _pump(tester, _harness().widget);
    await _enterEdit(tester);

    // No edit yet → Done is disabled.
    IconButton done() => tester.widget<IconButton>(
      find.byKey(const Key('profileComposeDoneButton')),
    );
    expect(done().onPressed, isNull);

    // A size toggle mutates the working layout → Done enables.
    await tester.tap(find.byKey(const Key('compositionSizeToggle_card')));
    await tester.pumpAndSettle();
    expect(done().onPressed, isNotNull);
  });

  testWidgets('a save failure surfaces the failure snackbar', (tester) async {
    await _pump(
      tester,
      _harness(setResult: () => left(const NetworkFailure())).widget,
    );
    await _enterEdit(tester);

    // Make a change, then attempt to save.
    await tester.tap(find.byKey(const Key('compositionSizeToggle_card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileComposeDoneButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const Key('profileComposeSaveFailedSnackBar')),
      findsOneWidget,
    );
  });

  testWidgets('edit mode exposes an Add affordance that opens the add-card '
      'sheet', (tester) async {
    await _pump(tester, _harness().widget);
    await _enterEdit(tester);

    expect(find.byKey(const Key('profileComposeAddButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('profileComposeAddButton')));
    await tester.pumpAndSettle();

    // The shared add-card catalog is open (its title marks the catalog).
    expect(find.byKey(const Key('addCatalogTitle')), findsOneWidget);
  });

  const cardOnlyProfile = Profile(
    id: 'owner-1',
    username: 'nico',
    displayName: 'Nico',
    avatarUrl: null,
    bio: null,
    theme: ProfileTheme.crimson,
    privacy: ProfilePrivacy.public,
    featuredPlatform: null,
    layout: [FullRow('card')],
  );

  ({ProviderContainer container, Widget widget}) acquireHarness(
    ProfileWidgetsRepository widgetsRepo, {
    List<NavigatorObserver> observers = const [],
  }) {
    final container = ProviderContainer(
      retry: (count, error) => null,
      overrides: [
        // A single-card profile so `startEditing` seeds [FullRow('card')] and the
        // acquire assertions (card, then the acquired Main) hold.
        profileRepositoryProvider.overrideWithValue(
          _FakeProfileRepo(profile: cardOnlyProfile),
        ),
        profileWidgetsRepositoryProvider.overrideWithValue(widgetsRepo),
        cardsRepositoryProvider.overrideWithValue(_ChessCardsRepo()),
        connectionsRepositoryProvider.overrideWithValue(_FakeConnectionsRepo()),
      ],
    );
    addTearDown(container.dispose);
    // ProfileScreen keeps the autoDispose mutation controller alive across an
    // in-flight write (its success-path invalidation fires and its error state
    // stays observable), so the harness no longer hand-rolls that listener.
    return (
      container: container,
      widget: UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorObservers: observers,
          home: const ProfileScreen(),
        ),
      ),
    );
  }

  Future<void> openAddSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(700, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.tap(find.byKey(const Key('profileEditButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileComposeAddButton')));
    await tester.pumpAndSettle();
  }

  testWidgets('(a) a Main write that settles before the sheet closes lands in '
      'the working layout once (dirty)', (tester) async {
    // The write is genuinely asynchronous; the append is driven by the widgets
    // read settling (the reactive listener), not by the sheet closing.
    final repo = _AcquireWidgetsRepo([
      _widget('card', ProfileWidgetKind.art),
    ], delay: const Duration(milliseconds: 50));
    final harness = acquireHarness(repo);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await openAddSheet(tester);

    await tester.tap(find.byKey(const Key('mainAddRow_chess')));
    await tester.pumpAndSettle();

    final state = harness.container.read(profileCompositionProvider);
    expect(state.working, const [FullRow('card'), FullRow('mn')]);
    expect(state.isDirty, isTrue);
  });

  testWidgets('(b) a Main acquired while the sheet is dismissed mid-write still '
      'lands when the read settles', (tester) async {
    // The write is held open, the sheet is dismissed WHILE it is in flight, and
    // only then does the write commit. The append must still land — it is driven
    // by the widgets read settling, not by how or when the sheet closed.
    final gate = Completer<void>();
    final repo = _AcquireWidgetsRepo([
      _widget('card', ProfileWidgetKind.art),
    ], gate: gate);
    final harness = acquireHarness(repo);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await openAddSheet(tester);

    // Start the (gated) write, then dismiss the sheet while it is still in flight.
    await tester.tap(find.byKey(const Key('mainAddRow_chess')));
    await tester.pump();
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mainAddRow_chess')), findsNothing);

    // The write commits only now, after the sheet is gone.
    gate.complete();
    await tester.pumpAndSettle();

    final state = harness.container.read(profileCompositionProvider);
    expect(state.working, const [FullRow('card'), FullRow('mn')]);
    expect(state.isDirty, isTrue);
  });

  testWidgets(
    'the acquire row is busy-guarded so a double-tap adds only once',
    (tester) async {
      final gate = Completer<void>();
      final repo = _AcquireWidgetsRepo([
        _widget('card', ProfileWidgetKind.art),
      ], gate: gate);
      final harness = acquireHarness(repo);

      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();
      await openAddSheet(tester);

      // First tap starts the gated write and disables the row.
      await tester.tap(find.byKey(const Key('mainAddRow_chess')));
      await tester.pump();
      // A second tap while the write is in flight is ignored.
      await tester.tap(find.byKey(const Key('mainAddRow_chess')));
      await tester.pump();
      expect(repo.addMainCalls, 1);

      // Release the write so the sheet can close cleanly.
      gate.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('a write failure during acquire surfaces through the controller '
      'and appends nothing', (tester) async {
    final repo = _AcquireWidgetsRepo(
      [_widget('card', ProfileWidgetKind.art)],
      delay: const Duration(milliseconds: 10),
      writeFailure: const NetworkFailure(),
    );
    final harness = acquireHarness(repo);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await openAddSheet(tester);

    await tester.tap(find.byKey(const Key('mainAddRow_chess')));
    await tester.pumpAndSettle();

    // The write failed → the read is never invalidated → nothing appended.
    expect(harness.container.read(profileCompositionProvider).working, const [
      FullRow('card'),
    ]);
    // The failure surfaced through the established controller error state, not as
    // a swallowed or unhandled error.
    expect(
      harness.container.read(profileWidgetsControllerProvider).hasError,
      isTrue,
    );
  });

  testWidgets('a write settling after the sheet was dismissed through another '
      'channel does not pop the screen beneath it', (tester) async {
    // Enter the danger window the ordinary acquire tests sidestep: the sheet is
    // dismissed by a DIFFERENT channel while the write is still in flight, and
    // the write then settles BEFORE the sheet's exit animation has finished — so
    // the row is still mounted, but its route is already no longer current (a
    // popped route is out of the present set the instant pop() flushes, well
    // before its exit animation disposes the subtree). The row's own delayed pop
    // must NOT fire, or it would land on the screen route beneath the sheet.
    final observer = _PopCountingObserver();
    final gate = Completer<void>();
    final repo = _AcquireWidgetsRepo([
      _widget('card', ProfileWidgetKind.art),
    ], gate: gate);
    final harness = acquireHarness(repo, observers: [observer]);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await openAddSheet(tester);

    // Start the gated write.
    await tester.tap(find.byKey(const Key('mainAddRow_chess')));
    await tester.pump();

    // Dismiss the sheet through a different channel WITHOUT settling its exit
    // animation. This is the ONLY intended pop; the row is still mounted.
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pump();

    // The write settles inside that window. Zero-duration pumps flush the write's
    // microtasks without advancing the exit animation, so the row is still
    // mounted when its post-await pop decision runs.
    gate.complete();
    await tester.pump();
    await tester.pump();

    // Only the sheet dismissal was popped; the row's guarded pop did not fire a
    // second, errant pop on the screen route beneath. (Without the route guard
    // this reads 2 — the row pops the now-current screen route.)
    expect(observer.pops, 1);

    // And once everything settles, the acquired card still lands (reactive
    // append), so guarding the pop costs nothing on the happy outcome.
    await tester.pumpAndSettle();
    expect(harness.container.read(profileCompositionProvider).working, const [
      FullRow('card'),
      FullRow('mn'),
    ]);
  });

  testWidgets('leaving edit mode renders the read view (AC7)', (tester) async {
    await _pump(tester, _harness().widget);
    await _enterEdit(tester);

    // Cancel returns to the read render: no drag handles, cards still shown.
    await tester.tap(find.byKey(const Key('profileComposeCancelButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('compositionDragHandle_card')), findsNothing);
    expect(find.byKey(personalizationCardKey('card')), findsOneWidget);
    expect(find.byKey(const Key('profileEditButton')), findsOneWidget);
  });

  testWidgets('dragging a card handle into a gap reorders the layout '
      '(best-effort DnD)', (tester) async {
    final harness = _harness();
    await _pump(tester, harness.widget);
    await _enterEdit(tester);

    // Drag the second card's handle up onto the very first gap.
    final handle = find.byKey(const Key('compositionDragHandle_card'));
    final gap = find.byKey(const Key('compositionGap_0'));
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(gap));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // 'card' moved to the first row.
    final working = harness.container.read(profileCompositionProvider).working;
    expect(working.first, const FullRow('card'));
  });

  testWidgets('deleting a card removes its widget and does not bounce back after '
      'the widgets read settles (A2)', (tester) async {
    // Two placed cards; the delete affordance dispatches to both controllers, so
    // the widget is deleted AND dropped from the working layout. The reactive
    // unplaced-fold then sees the reduced read and never re-adds it.
    final widgetsRepo = _DeletableWidgetsRepo([
      _widget('card', ProfileWidgetKind.art),
      _widget('extra', ProfileWidgetKind.art),
    ]);
    final container = ProviderContainer(
      retry: (count, error) => null,
      overrides: [
        profileRepositoryProvider.overrideWithValue(
          _FakeProfileRepo(profile: _twoCardProfile),
        ),
        profileWidgetsRepositoryProvider.overrideWithValue(widgetsRepo),
        cardsRepositoryProvider.overrideWithValue(_FakeCardsRepo()),
      ],
    );
    addTearDown(container.dispose);
    final widget = UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ProfileScreen(),
      ),
    );

    await _pump(tester, widget);
    await _enterEdit(tester);

    await tester.tap(find.byKey(const Key('compositionDelete_extra')));
    await tester.pumpAndSettle();

    final working = container.read(profileCompositionProvider).working;
    // Gone from the layout, and never re-appended by the reactive fold.
    expect(working, const [FullRow('card')]);
    // Falsifiable: a layout-only removal (no widget delete) leaves the widget in
    // the read; a repo that does not prune re-appends 'extra' on the refetch.
    expect(widgetsRepo.removed, contains('extra'));
  });

  testWidgets('a double-tap on a card delete affordance dispatches the removal '
      'exactly once (A5)', (tester) async {
    final widgetsRepo = _DeletableWidgetsRepo([
      _widget('card', ProfileWidgetKind.art),
      _widget('extra', ProfileWidgetKind.art),
    ]);
    final container = ProviderContainer(
      retry: (count, error) => null,
      overrides: [
        profileRepositoryProvider.overrideWithValue(
          _FakeProfileRepo(profile: _twoCardProfile),
        ),
        profileWidgetsRepositoryProvider.overrideWithValue(widgetsRepo),
        cardsRepositoryProvider.overrideWithValue(_FakeCardsRepo()),
      ],
    );
    addTearDown(container.dispose);
    final widget = UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ProfileScreen(),
      ),
    );

    await _pump(tester, widget);
    await _enterEdit(tester);

    // Two taps with NO pump between them: both land while the button is still
    // mounted (the working-layout rebuild that disposes it has not run yet). The
    // per-instance single-fire guard must collapse them into one removal.
    final delete = find.byKey(const Key('compositionDelete_extra'));
    await tester.tap(delete);
    await tester.tap(delete, warnIfMissed: false);
    await tester.pumpAndSettle();

    // Falsifiable: the unguarded button dispatches both taps → two remove calls.
    expect(widgetsRepo.removed, ['extra']);
  });

  testWidgets('deleting the first card leaves the successor delete live on its '
      'first tap (A6)', (tester) async {
    final widgetsRepo = _DeletableWidgetsRepo([
      _widget('card', ProfileWidgetKind.art),
      _widget('extra', ProfileWidgetKind.art),
    ]);
    final container = ProviderContainer(
      retry: (count, error) => null,
      overrides: [
        profileRepositoryProvider.overrideWithValue(
          _FakeProfileRepo(profile: _twoCardProfile),
        ),
        profileWidgetsRepositoryProvider.overrideWithValue(widgetsRepo),
        cardsRepositoryProvider.overrideWithValue(_FakeCardsRepo()),
      ],
    );
    addTearDown(container.dispose);
    final widget = UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ProfileScreen(),
      ),
    );

    await _pump(tester, widget);
    await _enterEdit(tester);

    // Delete the first card; its successor slides into row 0's tree slot.
    await tester.tap(find.byKey(const Key('compositionDelete_card')));
    await tester.pumpAndSettle();
    expect(container.read(profileCompositionProvider).working, const [
      FullRow('extra'),
    ]);

    // The successor's delete must fire on its FIRST tap. Falsifiable: without a
    // per-card key on _DeleteButton, 'extra' adopts 'card's recycled _busy == true
    // via positional reuse and swallows this tap.
    await tester.tap(find.byKey(const Key('compositionDelete_extra')));
    await tester.pumpAndSettle();

    expect(widgetsRepo.removed, contains('extra'));
    expect(container.read(profileCompositionProvider).working, isEmpty);
  });
}

// Two placed cards so the delete affordance and the no-bounce-back reactive fold
// are exercised: startEditing seeds [FullRow('card'), FullRow('extra')].
const _twoCardProfile = Profile(
  id: 'owner-1',
  username: 'nico',
  displayName: 'Nico',
  avatarUrl: null,
  bio: null,
  theme: ProfileTheme.crimson,
  privacy: ProfilePrivacy.public,
  featuredPlatform: null,
  layout: [FullRow('card'), FullRow('extra')],
);
