import 'dart:async';

import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/profile/domain/art_framing.dart';
import 'package:featgg/src/features/profile/domain/profile.dart';
import 'package:featgg/src/features/profile/domain/profile_layout.dart';
import 'package:featgg/src/features/profile/domain/profile_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_repository.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_repository.dart';
import 'package:featgg/src/features/profile/presentation/profile_composition_controller.dart';
import 'package:featgg/src/features/profile/presentation/profile_provider.dart';
import 'package:featgg/src/features/profile/presentation/profile_widgets_provider.dart';
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
      kind: ProfileWidgetKind.art,
      platform: null,
      position: position,
      isEnabled: enabled,
    );

final _widgets = [_widget('a'), _widget('b'), _widget('c')];
const _layout = [FullRow('a'), PairRow(left: 'b', right: 'c')];

/// The fixture profile carrying [layout]. A session seeds from the whole
/// profile — its identity as well as its rows — so the entry point takes one.
Profile _profileWith(List<ProfileLayoutRow> layout) => Profile(
  id: _profile.id,
  username: _profile.username,
  displayName: _profile.displayName,
  avatarUrl: null,
  bio: null,
  theme: _profile.theme,
  privacy: _profile.privacy,
  featuredPlatform: null,
  layout: layout,
);

/// Fake repository whose layout-write outcome is injected; records the fetch
/// count so a post-save profile re-read is observable. [setFuture] holds the
/// write pending so the disposal / concurrency windows are testable.
final class _FakeRepository implements ProfileRepository {
  _FakeRepository({this.setResult, this.setFuture, this.updateResult});

  final Either<Failure, Unit> Function()? setResult;
  final Future<Either<Failure, Unit>> Function()? setFuture;
  final Either<Failure, Profile> Function()? updateResult;
  int fetchCalls = 0;
  int setCalls = 0;
  int updateCalls = 0;
  List<ProfileLayoutRow>? lastSaved;
  ProfileEdit? lastEdit;

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() async {
    fetchCalls++;
    return right(_profile);
  }

  @override
  Future<Either<Failure, Unit>> setMyLayout(List<ProfileLayoutRow> rows) {
    setCalls++;
    lastSaved = rows;
    if (setFuture != null) return setFuture!();
    return Future.value(setResult?.call() ?? right(unit));
  }

  @override
  Future<Either<Failure, Profile>> updateMyProfile(ProfileEdit edit) async {
    updateCalls++;
    lastEdit = edit;
    return updateResult?.call() ?? right(_profile);
  }

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

/// Records the framings a save writes, so a test can tell what reached the
/// store from what only sat in the session.
final class _FakeWidgetsRepository implements ProfileWidgetsRepository {
  _FakeWidgetsRepository({this.failure});

  final Failure? failure;
  final List<String> writtenIds = [];
  final List<ArtFraming> writtenFramings = [];

  @override
  Future<Either<Failure, Unit>> setArtFraming(
    ProfileWidget widget,
    ArtFraming framing,
  ) async {
    if (failure != null) return left(failure!);
    writtenIds.add(widget.id);
    writtenFramings.add(framing);
    return right(unit);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// A container whose widget reads and writes are the fakes, so a framing save
/// has both the widgets to look up and a store to land in.
ProviderContainer _framingContainer(
  _FakeRepository repo,
  _FakeWidgetsRepository widgetsRepo,
) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      profileRepositoryProvider.overrideWithValue(repo),
      profileWidgetsRepositoryProvider.overrideWithValue(widgetsRepo),
      ownerProfileWidgetsProvider.overrideWith((ref) async => _widgets),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('startEditing seeds working==saved and is not dirty', () {
    final container = _container(_FakeRepository());
    final notifier = container.read(profileCompositionProvider.notifier);

    notifier.startEditing(_profileWith(_layout), _widgets);
    final state = container.read(profileCompositionProvider);

    expect(state.editing, isTrue);
    expect(state.working, _layout);
    expect(state.saved, _layout);
    expect(state.isDirty, isFalse);
  });

  test('startEditing on an unarranged profile bootstraps every widget as a full '
      'row in position order, with an empty saved base', () {
    final container = _container(_FakeRepository());
    final notifier = container.read(profileCompositionProvider.notifier);

    // Deliberately unordered input with one hidden widget.
    final widgets = [
      _widgetAt('c', 2),
      _widgetAt('a', 0),
      _widgetAt('b', 1, enabled: false),
      _widgetAt('d', 3),
    ];
    notifier.startEditing(_profileWith(const []), widgets);
    final state = container.read(profileCompositionProvider);

    expect(state.editing, isTrue);
    // Sorted by position, each a full row — the hidden one included, since
    // the editor is the only place its owner can reach it.
    expect(state.working, const [
      FullRow('a'),
      FullRow('b'),
      FullRow('c'),
      FullRow('d'),
    ]);
    // Nothing is persisted yet, so a plain Save is dirty (persists the bootstrap).
    expect(state.saved, isEmpty);
    expect(state.isDirty, isTrue);
  });

  test(
    'startEditing on an unarranged profile seeds a Rank and a Main both as full rows (both are '
    'dual-size)',
    () {
      final container = _container(_FakeRepository());
      final notifier = container.read(profileCompositionProvider.notifier);

      // Rank and Main both support a full row, so each bootstraps as a FullRow.
      const rank = ProfileWidget(
        id: 'r',
        kind: ProfileWidgetKind.rank,
        platform: Platform.leagueOfLegends,
        position: 0,
        isEnabled: true,
      );
      const main = ProfileWidget(
        id: 'm',
        kind: ProfileWidgetKind.main,
        platform: Platform.steam,
        position: 1,
        isEnabled: true,
      );

      notifier.startEditing(_profileWith(const []), const [rank, main]);
      final state = container.read(profileCompositionProvider);

      // Category order, not add order: what-I-play (Main) reads before
      // how-good-I-am (Rank) even though the rank was added first.
      expect(state.working, const [FullRow('m'), FullRow('r')]);
    },
  );

  test(
    'startEditing on an unarranged profile seeds in the catalog category order, position breaking '
    'ties, kinds outside the model last',
    () {
      final container = _container(_FakeRepository());
      final notifier = container.read(profileCompositionProvider.notifier);

      ProfileWidget kindAt(
        String id,
        ProfileWidgetKind kind,
        int position, {
        Platform? platform,
      }) => ProfileWidget(
        id: id,
        kind: kind,
        platform: platform,
        position: position,
        isEnabled: true,
      );

      // Add order is deliberately the reverse of the category order.
      notifier.startEditing(_profileWith(const []), [
        kindAt('v', ProfileWidgetKind.art, 0),
        kindAt('r', ProfileWidgetKind.rank, 1, platform: Platform.chess),
        kindAt('p', ProfileWidgetKind.passport, 2),
        kindAt('m', ProfileWidgetKind.main, 3, platform: Platform.steam),
        kindAt('s', ProfileWidgetKind.showcase, 4, platform: Platform.steam),
        kindAt(
          'g',
          ProfileWidgetKind.gameCollector,
          5,
          platform: Platform.steam,
        ),
        kindAt('t', ProfileWidgetKind.art, 6),
        kindAt(
          'c',
          ProfileWidgetKind.completionist,
          7,
          platform: Platform.steam,
        ),
      ]);
      final state = container.read(profileCompositionProvider);

      // who I am → what I play → how good I am → what I achieved (showcase
      // before completionist by position) → what I own → art; the legacy
      // template trails everything the category model places.
      expect(state.working, const [
        FullRow('p'),
        FullRow('m'),
        FullRow('r'),
        FullRow('s'),
        FullRow('c'),
        FullRow('g'),
        FullRow('v'),
        FullRow('t'),
      ]);
    },
  );

  test(
    'cancelling a bootstrap composition keeps nothing (saved stays empty)',
    () {
      final container = _container(_FakeRepository());
      final notifier = container.read(profileCompositionProvider.notifier);

      notifier.startEditing(_profileWith(const []), [
        _widget('a'),
        _widget('b'),
      ]);
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
    notifier.startEditing(_profileWith(const []), _widgets);
    final composed = container.read(profileCompositionProvider).working;
    await notifier.save();
    expect(container.read(profileCompositionProvider).saved, composed);

    // The profile read is still stale while the refetch is in flight, so the Edit
    // button passes an empty layout — startEditing must keep the saved
    // composition rather than wipe the editor blank.
    notifier.startEditing(_profileWith(const []), _widgets);
    final state = container.read(profileCompositionProvider);
    expect(state.working, composed);
    expect(state.saved, composed);
  });

  test('a fresh-mount edit seeds from the passed layout (saved is empty)', () {
    final container = _container(_FakeRepository());
    final notifier = container.read(profileCompositionProvider.notifier);

    // No prior composition in the controller → the passed layout is authoritative.
    notifier.startEditing(_profileWith(_layout), _widgets);
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
      notifier.startEditing(_profileWith(const []), _widgets);
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

    notifier.startEditing(_profileWith(_layout), _widgets);
    notifier.onToggleSize('a'); // full → orphan half
    final state = container.read(profileCompositionProvider);

    expect(state.isDirty, isTrue);
    expect(state.saved, _layout);
    expect(state.working, isNot(_layout));
  });

  group('removeCardFromLayout', () {
    test('drops the id from working and marks dirty (saved untouched)', () {
      final container = _container(_FakeRepository());
      final notifier = container.read(profileCompositionProvider.notifier);

      notifier.startEditing(_profileWith(_layout), _widgets);
      notifier.removeCardFromLayout('a'); // the full 'a' row

      final state = container.read(profileCompositionProvider);
      expect(state.working, const [PairRow(left: 'b', right: 'c')]);
      expect(state.isDirty, isTrue);
      expect(state.saved, _layout);
    });

    test('is a no-op while saving (mid-save snapshot intact)', () async {
      final completer = Completer<Either<Failure, Unit>>();
      final repo = _FakeRepository(setFuture: () => completer.future);
      final container = _container(repo);
      final notifier = container.read(profileCompositionProvider.notifier);

      notifier.startEditing(_profileWith(_layout), _widgets);
      notifier.onToggleSize('a'); // make dirty so save persists
      final sent = container.read(profileCompositionProvider).working;
      final saveFuture = notifier.save(); // saving := true, then awaits

      // A delete between Done and the network resolving must be ignored.
      notifier.removeCardFromLayout('a');
      expect(container.read(profileCompositionProvider).working, sent);

      completer.complete(right(unit));
      await saveFuture;

      // saved is exactly the snapshot that was sent, never a post-Done mutation.
      expect(container.read(profileCompositionProvider).saved, sent);
    });
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
    notifier.startEditing(_profileWith(_layout), _widgets);
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

      notifier.startEditing(_profileWith(_layout), _widgets);
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

    notifier.startEditing(_profileWith(_layout), _widgets);
    notifier.onToggleSize('a');
    await notifier.save();
    expect(container.read(profileCompositionProvider).saveFailed, isTrue);

    notifier.acknowledgeSaveFailure();
    expect(container.read(profileCompositionProvider).saveFailed, isFalse);
  });

  test('cancelEditing restores saved and leaves edit mode', () {
    final container = _container(_FakeRepository());
    final notifier = container.read(profileCompositionProvider.notifier);

    notifier.startEditing(_profileWith(_layout), _widgets);
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

    notifier.startEditing(_profileWith(_layout), _widgets);
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

      notifier.startEditing(_profileWith(_layout), _widgets);
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

      notifier.startEditing(_profileWith(_layout), _widgets);
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
        notifier.startEditing(_profileWith(_layout), _widgets);

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

    test('appends a Rank (now dual-size) as a full row', () {
      final container = _container(_FakeRepository());
      final notifier = container.read(profileCompositionProvider.notifier);
      notifier.startEditing(_profileWith(_layout), _widgets);

      // Rank supports a full row, so an acquired Rank folds in as a FullRow.
      const rank = ProfileWidget(
        id: 'r',
        kind: ProfileWidgetKind.rank,
        platform: Platform.leagueOfLegends,
        position: 3,
        isEnabled: true,
      );
      notifier.appendUnplacedWidgets([..._widgets, rank]);

      expect(
        container.read(profileCompositionProvider).working.last,
        const FullRow('r'),
      );
    });

    test('does not append a disabled widget', () {
      final container = _container(_FakeRepository());
      final notifier = container.read(profileCompositionProvider.notifier);
      notifier.startEditing(_profileWith(_layout), _widgets);

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
      notifier.startEditing(_profileWith(_layout), _widgets);

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

        notifier.startEditing(_profileWith(_layout), _widgets);
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
      notifier.startEditing(_profileWith(_layout), _widgets);

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

  group('the identity the session carries alongside the arrangement', () {
    test('opens seeded from the profile and clean', () {
      final container = _container(_FakeRepository());
      final notifier = container.read(profileCompositionProvider.notifier);

      notifier.startEditing(_profileWith(_layout), _widgets);
      final state = container.read(profileCompositionProvider);

      expect(state.draft?.displayName, 'Nico');
      expect(state.draft?.theme, ProfileTheme.crimson);
      expect(state.isDirty, isFalse);
    });

    test('opens clean over a profile whose stored bio is only whitespace', () {
      // The editors produce a trimmed, empty-as-null bio. Seeding the raw value
      // would open every such profile dirty and offer a Done that writes
      // nothing the owner asked for.
      const padded = Profile(
        id: 'owner-1',
        username: 'nico',
        displayName: '  Nico  ',
        avatarUrl: null,
        bio: '   ',
        theme: ProfileTheme.crimson,
        privacy: ProfilePrivacy.public,
        featuredPlatform: null,
        layout: _layout,
      );
      final container = _container(_FakeRepository());
      final notifier = container.read(profileCompositionProvider.notifier);

      notifier.startEditing(padded, _widgets);
      final state = container.read(profileCompositionProvider);

      expect(state.draft?.displayName, 'Nico');
      expect(state.draft?.bio, isNull);
      expect(state.isDirty, isFalse);
    });

    test('an identity edit is dirty and is what Done writes', () async {
      final repo = _FakeRepository();
      final container = _container(repo);
      final notifier = container.read(profileCompositionProvider.notifier);
      notifier.startEditing(_profileWith(_layout), _widgets);

      notifier.editIdentity(displayName: 'Nico F', bio: 'gg');
      expect(container.read(profileCompositionProvider).isDirty, isTrue);

      await notifier.save();

      expect(repo.updateCalls, 1);
      expect(repo.lastEdit?.displayName, 'Nico F');
      expect(repo.lastEdit?.bio, 'gg');
      // Nothing moved, so the arrangement is not rewritten.
      expect(repo.setCalls, 0);
      expect(container.read(profileCompositionProvider).editing, isFalse);
    });

    test('a theme pick lands in the draft and writes nothing on its own', () {
      final repo = _FakeRepository();
      final container = _container(repo);
      final notifier = container.read(profileCompositionProvider.notifier);
      notifier.startEditing(_profileWith(_layout), _widgets);

      notifier.selectTheme(ProfileTheme.abyss);
      final state = container.read(profileCompositionProvider);

      // The render re-tints off the draft; the write waits for Done.
      expect(state.draft?.theme, ProfileTheme.abyss);
      expect(state.isDirty, isTrue);
      expect(repo.updateCalls, 0);
    });

    test('a cover pick lands in the draft', () {
      final container = _container(_FakeRepository());
      final notifier = container.read(profileCompositionProvider.notifier);
      notifier.startEditing(_profileWith(_layout), _widgets);

      notifier.selectHeaderPlatform(Platform.steam);
      expect(
        container.read(profileCompositionProvider).draft?.headerPlatform,
        Platform.steam,
      );
    });

    test('cancel restores the identity, not just the arrangement', () {
      final container = _container(_FakeRepository());
      final notifier = container.read(profileCompositionProvider.notifier);
      notifier.startEditing(_profileWith(_layout), _widgets);

      notifier.editIdentity(displayName: 'Someone else', bio: 'oops');
      notifier.selectTheme(ProfileTheme.abyss);
      notifier.cancelEditing();
      final state = container.read(profileCompositionProvider);

      expect(state.editing, isFalse);
      expect(state.draft?.displayName, 'Nico');
      expect(state.draft?.bio, isNull);
      expect(state.draft?.theme, ProfileTheme.crimson);
    });

    test('an arrangement-only change does not rewrite the identity', () async {
      final repo = _FakeRepository();
      final container = _container(repo);
      final notifier = container.read(profileCompositionProvider.notifier);
      notifier.startEditing(_profileWith(_layout), _widgets);

      notifier.onToggleSize('a');
      await notifier.save();

      expect(repo.setCalls, 1);
      expect(repo.updateCalls, 0);
    });

    test('a failed identity write keeps what was typed and holds the session '
        'open', () async {
      final repo = _FakeRepository(
        updateResult: () => left(const NetworkFailure()),
      );
      final container = _container(repo);
      final notifier = container.read(profileCompositionProvider.notifier);
      notifier.startEditing(_profileWith(_layout), _widgets);

      notifier.editIdentity(displayName: 'Nico F', bio: 'gg');
      notifier.onToggleSize('a');
      await notifier.save();
      final state = container.read(profileCompositionProvider);

      expect(state.saveFailed, isTrue);
      expect(state.editing, isTrue);
      // Typed text has no other copy — rolling it back would lose it.
      expect(state.draft?.displayName, 'Nico F');
      expect(state.draft?.bio, 'gg');
      // Fails fast: the arrangement is not written over a half-failed save.
      expect(repo.setCalls, 0);
    });

    test('an arrangement that fails after the identity landed does not rewrite '
        'the identity on the next Done', () async {
      final repo = _FakeRepository(
        setResult: () => left(const NetworkFailure()),
      );
      final container = _container(repo);
      final notifier = container.read(profileCompositionProvider.notifier);
      notifier.startEditing(_profileWith(_layout), _widgets);

      notifier.editIdentity(displayName: 'Nico F', bio: null);
      notifier.onToggleSize('a');
      await notifier.save();

      expect(repo.updateCalls, 1);
      expect(container.read(profileCompositionProvider).saveFailed, isTrue);
      expect(container.read(profileCompositionProvider).editing, isTrue);

      // The identity is persisted; only the arrangement rolled back. A second
      // Done must not send the same name again.
      await notifier.save();
      expect(repo.updateCalls, 1);
    });

    test('the identity editors are inert while a save is in flight', () async {
      final gate = Completer<Either<Failure, Unit>>();
      final repo = _FakeRepository(setFuture: () => gate.future);
      final container = _container(repo);
      final notifier = container.read(profileCompositionProvider.notifier);
      notifier.startEditing(_profileWith(_layout), _widgets);

      notifier.onToggleSize('a');
      final saving = notifier.save();

      // A save has snapshotted the draft and must persist exactly that.
      notifier.selectTheme(ProfileTheme.abyss);
      notifier.editIdentity(displayName: 'Nico F', bio: null);
      final midSave = container.read(profileCompositionProvider);
      expect(midSave.draft?.theme, ProfileTheme.crimson);
      expect(midSave.draft?.displayName, 'Nico');

      gate.complete(right(unit));
      await saving;
    });
  });

  group('framing is an edit like any other', () {
    const moved = ArtFraming(x: 0.2, y: 0.8);

    test('moving a picture is enough to have something to save', () {
      // The whole defect: the picture moved, the session said nothing had
      // changed, and Done stayed closed against an edit just made.
      final container = _container(_FakeRepository());
      final notifier = container.read(profileCompositionProvider.notifier);
      notifier.startEditing(_profileWith(_layout), _widgets);
      expect(container.read(profileCompositionProvider).isDirty, isFalse);

      notifier.setFraming('a', was: ArtFraming.center, now: moved);

      expect(container.read(profileCompositionProvider).isDirty, isTrue);
    });

    test('putting it back where it was leaves nothing to save', () {
      final container = _container(_FakeRepository());
      final notifier = container.read(profileCompositionProvider.notifier);
      notifier.startEditing(_profileWith(_layout), _widgets);

      notifier.setFraming('a', was: ArtFraming.center, now: moved);
      // A later drag reports where the picture started, not where the previous
      // one left it, so the session still compares against the beginning.
      notifier.setFraming('a', was: ArtFraming.center, now: ArtFraming.center);

      expect(container.read(profileCompositionProvider).isDirty, isFalse);
    });

    test('cancel drops it', () {
      final container = _container(_FakeRepository());
      final notifier = container.read(profileCompositionProvider.notifier);
      notifier.startEditing(_profileWith(_layout), _widgets);
      notifier.setFraming('a', was: ArtFraming.center, now: moved);

      notifier.cancelEditing();

      final state = container.read(profileCompositionProvider);
      expect(state.framings, isEmpty);
      expect(state.isDirty, isFalse);
    });

    test('nothing reaches the store before Done', () async {
      final widgetsRepo = _FakeWidgetsRepository();
      final container = _framingContainer(_FakeRepository(), widgetsRepo);
      await container.read(ownerProfileWidgetsProvider.future);
      final notifier = container.read(profileCompositionProvider.notifier);
      notifier.startEditing(_profileWith(_layout), _widgets);

      notifier.setFraming('a', was: ArtFraming.center, now: moved);

      expect(widgetsRepo.writtenIds, isEmpty);
    });

    test('Done writes it', () async {
      final widgetsRepo = _FakeWidgetsRepository();
      final container = _framingContainer(_FakeRepository(), widgetsRepo);
      await container.read(ownerProfileWidgetsProvider.future);
      final notifier = container.read(profileCompositionProvider.notifier);
      notifier.startEditing(_profileWith(_layout), _widgets);
      notifier.setFraming('a', was: ArtFraming.center, now: moved);

      await notifier.save();

      expect(widgetsRepo.writtenIds, ['a']);
      expect(widgetsRepo.writtenFramings, [moved]);
      expect(container.read(profileCompositionProvider).editing, isFalse);
    });

    test('a picture nobody moved is not rewritten', () async {
      final widgetsRepo = _FakeWidgetsRepository();
      final container = _framingContainer(_FakeRepository(), widgetsRepo);
      await container.read(ownerProfileWidgetsProvider.future);
      final notifier = container.read(profileCompositionProvider.notifier);
      notifier.startEditing(_profileWith(_layout), _widgets);
      notifier.setFraming('a', was: ArtFraming.center, now: moved);
      notifier.onToggleSize('a');

      await notifier.save();

      expect(widgetsRepo.writtenIds, ['a']);
    });

    test('a framing that will not write fails the save loudly', () async {
      final widgetsRepo = _FakeWidgetsRepository(
        failure: const NetworkFailure(),
      );
      final container = _framingContainer(_FakeRepository(), widgetsRepo);
      await container.read(ownerProfileWidgetsProvider.future);
      final notifier = container.read(profileCompositionProvider.notifier);
      notifier.startEditing(_profileWith(_layout), _widgets);
      notifier.setFraming('a', was: ArtFraming.center, now: moved);

      await notifier.save();

      final state = container.read(profileCompositionProvider);
      expect(state.saveFailed, isTrue);
      expect(state.editing, isTrue, reason: 'the owner keeps the session');
    });
  });
}
