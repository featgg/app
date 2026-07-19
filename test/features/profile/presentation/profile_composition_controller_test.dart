import 'dart:async';

import 'package:featgg/src/core/error/failure.dart';
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
ProfileWidget _widget(String id) => ProfileWidget(
  id: id,
  kind: ProfileWidgetKind.template,
  platform: null,
  position: 0,
  isEnabled: true,
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
}
