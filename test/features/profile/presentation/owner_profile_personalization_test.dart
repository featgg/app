import 'dart:async';

import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/profile.dart';
import 'package:featgg/src/features/profile/domain/profile_layout.dart';
import 'package:featgg/src/features/profile/domain/profile_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_repository.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_repository.dart';
import 'package:featgg/src/features/profile/presentation/owner_profile_personalization.dart';
import 'package:featgg/src/features/profile/presentation/personalization_archetype_cards.dart';
import 'package:featgg/src/features/profile/presentation/profile_composition_controller.dart';
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
  size: ProfileWidgetSize.small,
);

final _widgets = [
  _widget('idc', ProfileWidgetKind.passport), // identity → full only
  _widget('card', ProfileWidgetKind.template), // fallback → both sizes
];

final class _FakeProfileRepo implements ProfileRepository {
  _FakeProfileRepo({this.setResult});

  final Either<Failure, Unit> Function()? setResult;

  @override
  Future<Either<Failure, Unit>> setMyLayout(
    List<ProfileLayoutRow> rows,
  ) async => setResult?.call() ?? right(unit);

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() async => right(_profile);

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
    required ProfileWidgetSize size,
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
      size: size,
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
    ],
  );
  addTearDown(container.dispose);
  final widget = UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: OwnerProfilePersonalization(profile: _profile),
      ),
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
  await tester.tap(find.byKey(const Key('profileComposeEditButton')));
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
    InkWell done() => tester.widget<InkWell>(
      find.byKey(const Key('profileComposeDoneButton')),
    );
    expect(done().onTap, isNull);

    // A size toggle mutates the working layout → Done enables.
    await tester.tap(find.byKey(const Key('compositionSizeToggle_card')));
    await tester.pumpAndSettle();
    expect(done().onTap, isNotNull);
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

    // The shared add-card sheet is open (its mode toggle is present).
    expect(find.byKey(const Key('addCardModeToggle')), findsOneWidget);
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
        profileRepositoryProvider.overrideWithValue(_FakeProfileRepo()),
        profileWidgetsRepositoryProvider.overrideWithValue(widgetsRepo),
        cardsRepositoryProvider.overrideWithValue(_ChessCardsRepo()),
      ],
    );
    addTearDown(container.dispose);
    // Mirror ProfileScreen, which owns this surface in production and keeps the
    // autoDispose mutation controller alive across an in-flight write so its
    // success-path invalidation of the widgets read reliably fires (and its error
    // state is observable).
    container.listen(profileWidgetsControllerProvider, (_, _) {});
    return (
      container: container,
      widget: UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorObservers: observers,
          home: const Scaffold(
            body: OwnerProfilePersonalization(profile: cardOnlyProfile),
          ),
        ),
      ),
    );
  }

  Future<void> openAddSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(700, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.tap(find.byKey(const Key('profileComposeEditButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileComposeAddButton')));
    await tester.pumpAndSettle();
  }

  testWidgets('(a) a Main write that settles before the sheet closes lands in '
      'the working layout once (dirty)', (tester) async {
    // The write is genuinely asynchronous; the append is driven by the widgets
    // read settling (the reactive listener), not by the sheet closing.
    final repo = _AcquireWidgetsRepo([
      _widget('card', ProfileWidgetKind.template),
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
      _widget('card', ProfileWidgetKind.template),
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
        _widget('card', ProfileWidgetKind.template),
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
      [_widget('card', ProfileWidgetKind.template)],
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
      _widget('card', ProfileWidgetKind.template),
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
    expect(find.byKey(const Key('profileComposeEditButton')), findsOneWidget);
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

  testWidgets(
    'the last card clears the floating control bar at maximum scroll',
    (tester) async {
      // Phone-sized viewport with enough full-row cards to scroll past the fold.
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final widgets = [
        for (var i = 0; i < 6; i++) _widget('w$i', ProfileWidgetKind.template),
      ];
      const profile = Profile(
        id: 'owner-1',
        username: 'nico',
        displayName: 'Nico',
        avatarUrl: null,
        bio: null,
        theme: ProfileTheme.crimson,
        privacy: ProfilePrivacy.public,
        featuredPlatform: null,
        layout: [
          FullRow('w0'),
          FullRow('w1'),
          FullRow('w2'),
          FullRow('w3'),
          FullRow('w4'),
          FullRow('w5'),
        ],
      );

      final container = ProviderContainer(
        retry: (count, error) => null,
        overrides: [
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepo()),
          profileWidgetsRepositoryProvider.overrideWithValue(
            _FakeWidgetsRepo(widgets),
          ),
          cardsRepositoryProvider.overrideWithValue(_FakeCardsRepo()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: OwnerProfilePersonalization(profile: profile),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Jump to the very bottom of the scroll content.
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pumpAndSettle();

      // The last card's bottom edge sits above the control bar's top edge — the
      // reserved bottom inset keeps it from hiding behind the bar.
      final lastCardBottom = tester
          .getRect(find.byKey(personalizationCardKey('w5')))
          .bottom;
      final barTop = tester
          .getRect(find.byKey(const Key('profileComposeControlBar')))
          .top;
      expect(lastCardBottom, lessThanOrEqualTo(barTop));
    },
  );
}
