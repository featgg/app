import 'dart:async';

import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/profile/domain/profile.dart';
import 'package:featgg/src/features/profile/domain/profile_layout.dart';
import 'package:featgg/src/features/profile/domain/profile_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_repository.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/presentation/profile_composition_controller.dart';
import 'package:featgg/src/features/profile/presentation/profile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

const _profile = Profile(
  id: 'owner-1',
  username: 'nico',
  displayName: 'Nico',
  avatarUrl: null,
  bio: null,
  theme: ProfileTheme.crimson,
  privacy: ProfilePrivacy.public,
  featuredPlatform: null,
  layout: [
    FullRow('a'),
    PairRow(left: 'b', right: 'c'),
  ],
);

// Template widgets map to the fallback archetype, which supports both sizes.
ProfileWidget _widget(String id) => _widgetAt(id, 0);

ProfileWidget _widgetAt(String id, int position, {bool enabled = true}) =>
    ProfileWidget(
      id: id,
      kind: ProfileWidgetKind.template,
      platform: null,
      position: position,
      isEnabled: enabled,
      size: ProfileWidgetSize.small,
    );

final _widgets = [_widget('a'), _widget('b'), _widget('c')];
const _layout = [FullRow('a'), PairRow(left: 'b', right: 'c')];

/// Fake repository whose layout-write outcome is injected; records the fetch
/// count so a post-save profile re-read is observable. [setFuture] holds the
/// write pending so the disposal / concurrency windows are testable.
final class _FakeRepository implements ProfileRepository {
  _FakeRepository({this.setResult, this.setFuture});

  final Either<Failure, Unit> Function()? setResult;
  final Future<Either<Failure, Unit>> Function()? setFuture;
  int fetchCalls = 0;
  List<ProfileLayoutRow>? lastSaved;

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() async {
    fetchCalls++;
    return right(_profile);
  }

  @override
  Future<Either<Failure, Unit>> setMyLayout(List<ProfileLayoutRow> rows) {
    lastSaved = rows;
    if (setFuture != null) return setFuture!();
    return Future.value(setResult?.call() ?? right(unit));
  }

  @override
  Future<Either<Failure, Profile>> updateMyProfile(ProfileEdit edit) async =>
      right(_profile);

  @override
  Future<Either<Failure, Profile?>> fetchPublicProfile(String userId) async =>
      right(null);
}

ProviderContainer _container(_FakeRepository repo) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [profileRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('startEditing seeds working==saved and is not dirty', () {
    final container = _container(_FakeRepository());
    final notifier = container.read(profileCompositionProvider.notifier);

    notifier.startEditing(_layout, _widgets);
    final state = container.read(profileCompositionProvider);

    expect(state.editing, isTrue);
    expect(state.working, _layout);
    expect(state.saved, _layout);
    expect(state.isDirty, isFalse);
  });

  test('startComposing bootstraps enabled widgets as full rows in position '
      'order, excluding disabled, with an empty saved base', () {
    final container = _container(_FakeRepository());
    final notifier = container.read(profileCompositionProvider.notifier);

    // Deliberately unordered input with one disabled widget.
    final widgets = [
      _widgetAt('c', 2),
      _widgetAt('a', 0),
      _widgetAt('b', 1, enabled: false),
      _widgetAt('d', 3),
    ];
    notifier.startComposing(widgets);
    final state = container.read(profileCompositionProvider);

    expect(state.editing, isTrue);
    // Enabled widgets only, sorted by position, each a full row.
    expect(state.working, const [FullRow('a'), FullRow('c'), FullRow('d')]);
    // Nothing is persisted yet, so a plain Save is dirty (persists the bootstrap).
    expect(state.saved, isEmpty);
    expect(state.isDirty, isTrue);
  });

  test('startComposing seeds a half-only widget as a PairRow orphan and a '
      'dual-size widget as a FullRow', () {
    final container = _container(_FakeRepository());
    final notifier = container.read(profileCompositionProvider.notifier);

    // Rank is half-only (its archetype supports only half); Main supports full.
    const rank = ProfileWidget(
      id: 'r',
      kind: ProfileWidgetKind.rank,
      platform: Platform.leagueOfLegends,
      position: 0,
      isEnabled: true,
      size: ProfileWidgetSize.small,
    );
    const main = ProfileWidget(
      id: 'm',
      kind: ProfileWidgetKind.main,
      platform: Platform.steam,
      position: 1,
      isEnabled: true,
      size: ProfileWidgetSize.small,
    );

    notifier.startComposing(const [rank, main]);
    final state = container.read(profileCompositionProvider);

    // The half-only card can't be a full row, so it bootstraps as a single-slot
    // centered orphan; the dual-size card bootstraps as a full row.
    expect(state.working, const [PairRow(left: 'r'), FullRow('m')]);
  });

  test(
    'cancelling a bootstrap composition keeps nothing (saved stays empty)',
    () {
      final container = _container(_FakeRepository());
      final notifier = container.read(profileCompositionProvider.notifier);

      notifier.startComposing([_widget('a'), _widget('b')]);
      notifier.cancelEditing();
      final state = container.read(profileCompositionProvider);

      expect(state.editing, isFalse);
      expect(state.working, isEmpty);
      expect(state.saved, isEmpty);
    },
  );

  test('re-entering edit during a post-save refetch seeds from the saved '
      'composition, not a stale passed layout', () async {
    final container = _container(_FakeRepository());
    final notifier = container.read(profileCompositionProvider.notifier);

    // Compose and persist a first layout. Success commits it to `saved`.
    notifier.startComposing(_widgets);
    final composed = container.read(profileCompositionProvider).working;
    await notifier.save();
    expect(container.read(profileCompositionProvider).saved, composed);

    // The profile read is still stale while the refetch is in flight, so the Edit
    // button passes an empty layout — startEditing must keep the saved
    // composition rather than wipe the editor blank.
    notifier.startEditing(const [], _widgets);
    final state = container.read(profileCompositionProvider);
    expect(state.working, composed);
    expect(state.saved, composed);
  });

  test('a fresh-mount edit seeds from the passed layout (saved is empty)', () {
    final container = _container(_FakeRepository());
    final notifier = container.read(profileCompositionProvider.notifier);

    // No prior composition in the controller → the passed layout is authoritative.
    notifier.startEditing(_layout, _widgets);
    final state = container.read(profileCompositionProvider);
    expect(state.working, _layout);
    expect(state.saved, _layout);
  });

  test(
    'a successful save records hasPersisted; before that it is unset',
    () async {
      final container = _container(_FakeRepository());
      final notifier = container.read(profileCompositionProvider.notifier);

      // Fresh, and an un-saved bootstrap, both report no persisted knowledge.
      expect(container.read(profileCompositionProvider).hasPersisted, isFalse);
      notifier.startComposing(_widgets);
      expect(container.read(profileCompositionProvider).hasPersisted, isFalse);

      // A committed save flips it — the authoritative "controller knows the
      // persisted layout" signal the gate/seed rely on.
      await notifier.save();
      expect(container.read(profileCompositionProvider).hasPersisted, isTrue);
    },
  );

  group('showsCompositionSurface (mount gate)', () {
    test('editing always shows the surface, whatever the profile layout', () {
      expect(
        showsCompositionSurface(
          editing: true,
          hasPersisted: false,
          savedIsNotEmpty: false,
          profileHasLayout: false,
        ),
        isTrue,
      );
    });

    test('a fresh controller (nothing persisted) defers to the profile', () {
      expect(
        showsCompositionSurface(
          editing: false,
          hasPersisted: false,
          savedIsNotEmpty: false,
          profileHasLayout: true,
        ),
        isTrue,
      );
      expect(
        showsCompositionSurface(
          editing: false,
          hasPersisted: false,
          savedIsNotEmpty: false,
          profileHasLayout: false,
        ),
        isFalse,
      );
    });

    test('a just-saved composition holds through a stale-empty refetch', () {
      expect(
        showsCompositionSurface(
          editing: false,
          hasPersisted: true,
          savedIsNotEmpty: true,
          profileHasLayout: false,
        ),
        isTrue,
      );
    });

    test('a just-cleared composition routes to the grid despite a stale '
        'non-empty layout', () {
      // The precondition for the revive-then-pin defect: persisted, saved empty,
      // profile.layout still stale non-empty. Must be the grid, not the surface —
      // this is where the old `saved.isNotEmpty || layout.isNotEmpty` gate leaked.
      expect(
        showsCompositionSurface(
          editing: false,
          hasPersisted: true,
          savedIsNotEmpty: false,
          profileHasLayout: true,
        ),
        isFalse,
      );
    });

    test('a cleared composition stays on the grid across the whole refetch '
        '(cannot pin the owner on an empty surface)', () {
      bool gate(bool profileHasLayout) => showsCompositionSurface(
        editing: false,
        hasPersisted: true,
        savedIsNotEmpty: false,
        profileHasLayout: profileHasLayout,
      );
      // Stale non-empty during the refetch, and settled empty after it — grid on
      // both, so there is never an Edit surface to revive the cleared layout.
      expect(gate(true), isFalse);
      expect(gate(false), isFalse);
    });
  });

  test('a mutation marks the state dirty without touching saved', () {
    final container = _container(_FakeRepository());
    final notifier = container.read(profileCompositionProvider.notifier);

    notifier.startEditing(_layout, _widgets);
    notifier.onToggleSize('a'); // full → orphan half
    final state = container.read(profileCompositionProvider);

    expect(state.isDirty, isTrue);
    expect(state.saved, _layout);
    expect(state.working, isNot(_layout));
  });

  test('save success commits working, exits edit mode, and re-reads the '
      'profile', () async {
    final repo = _FakeRepository();
    final container = _container(repo);
    // Keep the profile read alive so the post-save invalidate re-fetches.
    container.listen(profileProvider, (_, _) {});
    await container.read(profileProvider.future);
    expect(repo.fetchCalls, 1);

    final notifier = container.read(profileCompositionProvider.notifier);
    notifier.startEditing(_layout, _widgets);
    notifier.onToggleSize('a');
    final working = container.read(profileCompositionProvider).working;

    await notifier.save();

    final state = container.read(profileCompositionProvider);
    expect(state.editing, isFalse);
    expect(state.saving, isFalse);
    expect(state.saved, working);
    expect(repo.lastSaved, working);

    await container.read(profileProvider.future);
    expect(repo.fetchCalls, 2);
  });

  test(
    'save failure rolls working back to saved and raises saveFailed',
    () async {
      final repo = _FakeRepository(
        setResult: () => left(const NetworkFailure()),
      );
      final container = _container(repo);
      final notifier = container.read(profileCompositionProvider.notifier);

      notifier.startEditing(_layout, _widgets);
      notifier.onToggleSize('a');
      await notifier.save();

      final state = container.read(profileCompositionProvider);
      expect(state.working, _layout); // rolled back to saved
      expect(state.saved, _layout);
      expect(state.saveFailed, isTrue);
      expect(state.editing, isTrue); // edit mode stays open
      expect(state.saving, isFalse);
    },
  );

  test('acknowledgeSaveFailure clears the one-shot flag', () async {
    final repo = _FakeRepository(setResult: () => left(const NetworkFailure()));
    final container = _container(repo);
    final notifier = container.read(profileCompositionProvider.notifier);

    notifier.startEditing(_layout, _widgets);
    notifier.onToggleSize('a');
    await notifier.save();
    expect(container.read(profileCompositionProvider).saveFailed, isTrue);

    notifier.acknowledgeSaveFailure();
    expect(container.read(profileCompositionProvider).saveFailed, isFalse);
  });

  test('cancelEditing restores saved and leaves edit mode', () {
    final container = _container(_FakeRepository());
    final notifier = container.read(profileCompositionProvider.notifier);

    notifier.startEditing(_layout, _widgets);
    notifier.onToggleSize('a');
    notifier.cancelEditing();

    final state = container.read(profileCompositionProvider);
    expect(state.editing, isFalse);
    expect(state.working, _layout);
  });

  test('save with no changes just exits edit mode without a write', () async {
    final repo = _FakeRepository();
    final container = _container(repo);
    final notifier = container.read(profileCompositionProvider.notifier);

    notifier.startEditing(_layout, _widgets);
    await notifier.save();

    expect(container.read(profileCompositionProvider).editing, isFalse);
    expect(repo.lastSaved, isNull); // no persistence attempted
  });

  test(
    'disposing the provider mid-save does not throw (autoDispose guard)',
    () async {
      final completer = Completer<Either<Failure, Unit>>();
      final repo = _FakeRepository(setFuture: () => completer.future);
      // Own the container so the manual dispose is the only one (no teardown).
      final container = ProviderContainer(
        retry: (count, error) => null,
        overrides: [profileRepositoryProvider.overrideWithValue(repo)],
      );
      final notifier = container.read(profileCompositionProvider.notifier);

      notifier.startEditing(_layout, _widgets);
      notifier.onToggleSize('a');
      final saveFuture = notifier.save(); // suspends on the pending write

      container.dispose(); // the notifier disposes while the save is in flight
      completer.complete(right(unit)); // resolves after disposal

      // Without the ref.mounted guard the post-await state write throws
      // UnmountedRefException; the guard makes this complete cleanly.
      await expectLater(saveFuture, completes);
    },
  );

  test(
    'a mutation attempted mid-save is ignored and cannot corrupt saved',
    () async {
      final completer = Completer<Either<Failure, Unit>>();
      final repo = _FakeRepository(setFuture: () => completer.future);
      final container = _container(repo);
      final notifier = container.read(profileCompositionProvider.notifier);

      notifier.startEditing(_layout, _widgets);
      notifier.onToggleSize('a');
      final sent = container.read(profileCompositionProvider).working;

      final saveFuture = notifier.save(); // saving := true, then awaits
      // A drag/toggle between Done and the network resolving must be ignored.
      notifier.onGapDrop('b', 0);
      expect(container.read(profileCompositionProvider).working, sent);

      completer.complete(right(unit));
      await saveFuture;

      // saved is exactly the snapshot that was sent, never a post-Done mutation.
      expect(container.read(profileCompositionProvider).saved, sent);
    },
  );

  group('appendUnplacedWidgets', () {
    test(
      'appends an unplaced enabled widget as a full row and marks dirty',
      () {
        final container = _container(_FakeRepository());
        final notifier = container.read(profileCompositionProvider.notifier);
        notifier.startEditing(_layout, _widgets);

        // The owner acquired 'd' mid-edit; the refreshed list is the superset.
        notifier.appendUnplacedWidgets([..._widgets, _widgetAt('d', 3)]);

        final state = container.read(profileCompositionProvider);
        expect(state.working, const [
          FullRow('a'),
          PairRow(left: 'b', right: 'c'),
          FullRow('d'),
        ]);
        expect(state.isDirty, isTrue);
      },
    );

    test('appends a half-only widget as a single-slot PairRow orphan', () {
      final container = _container(_FakeRepository());
      final notifier = container.read(profileCompositionProvider.notifier);
      notifier.startEditing(_layout, _widgets);

      // Rank is half-only: even though it was not in the widget set captured at
      // startEditing, the append recaptures support so it seeds as an orphan.
      const rank = ProfileWidget(
        id: 'r',
        kind: ProfileWidgetKind.rank,
        platform: Platform.leagueOfLegends,
        position: 3,
        isEnabled: true,
        size: ProfileWidgetSize.small,
      );
      notifier.appendUnplacedWidgets([..._widgets, rank]);

      expect(
        container.read(profileCompositionProvider).working.last,
        const PairRow(left: 'r'),
      );
    });

    test('does not append a disabled widget', () {
      final container = _container(_FakeRepository());
      final notifier = container.read(profileCompositionProvider.notifier);
      notifier.startEditing(_layout, _widgets);

      notifier.appendUnplacedWidgets([
        ..._widgets,
        _widgetAt('d', 3, enabled: false),
      ]);

      final state = container.read(profileCompositionProvider);
      expect(state.working, _layout);
      expect(state.isDirty, isFalse);
    });

    test('does not append an already-placed widget (no-op, stays clean)', () {
      final container = _container(_FakeRepository());
      final notifier = container.read(profileCompositionProvider.notifier);
      notifier.startEditing(_layout, _widgets);

      notifier.appendUnplacedWidgets(_widgets);

      final state = container.read(profileCompositionProvider);
      expect(state.working, _layout);
      expect(state.isDirty, isFalse);
    });

    test(
      'an emission arriving mid-save cannot corrupt the sent snapshot',
      () async {
        final completer = Completer<Either<Failure, Unit>>();
        final repo = _FakeRepository(setFuture: () => completer.future);
        final container = _container(repo);
        final notifier = container.read(profileCompositionProvider.notifier);

        notifier.startEditing(_layout, _widgets);
        notifier.onToggleSize('a'); // make it dirty so save actually persists
        final sent = container.read(profileCompositionProvider).working;
        final saveFuture = notifier.save(); // saving := true, then awaits

        // A widgets refetch landing mid-save (via the reactive append) must be
        // dropped, never folded into the layout being persisted.
        notifier.appendUnplacedWidgets([..._widgets, _widgetAt('d', 3)]);
        expect(container.read(profileCompositionProvider).working, sent);

        completer.complete(right(unit));
        await saveFuture;

        // saved is exactly the snapshot that was sent, uncorrupted by the emission.
        expect(container.read(profileCompositionProvider).saved, sent);
      },
    );

    test('repeated emissions of the same list append each widget at most once '
        '(idempotent)', () {
      final container = _container(_FakeRepository());
      final notifier = container.read(profileCompositionProvider.notifier);
      notifier.startEditing(_layout, _widgets);

      final refreshed = [..._widgets, _widgetAt('d', 3)];
      notifier.appendUnplacedWidgets(refreshed);
      notifier.appendUnplacedWidgets(refreshed); // a second, redundant emission

      // 'd' is added exactly once; the second emission is a no-op.
      expect(container.read(profileCompositionProvider).working, const [
        FullRow('a'),
        PairRow(left: 'b', right: 'c'),
        FullRow('d'),
      ]);
    });

    test('is a no-op when not editing (guards the working layout)', () {
      final container = _container(_FakeRepository());
      final notifier = container.read(profileCompositionProvider.notifier);

      // No edit session started → the surface is not composing.
      notifier.appendUnplacedWidgets(_widgets);

      final state = container.read(profileCompositionProvider);
      expect(state.editing, isFalse);
      expect(state.working, isEmpty);
    });
  });
}
