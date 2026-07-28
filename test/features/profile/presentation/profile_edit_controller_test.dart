import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/profile/domain/profile_domain.dart';
import 'package:featgg/src/features/profile/presentation/profile_presentation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

const _profile = Profile(
  id: 'user-1',
  username: 'testuser',
  displayName: 'Test User',
  avatarUrl: null,
  bio: 'My bio',
  theme: ProfileTheme.crimson,
  privacy: ProfilePrivacy.public,
  featuredPlatform: null,
);

/// The form for [_profile]. Keyed by the profile it opens on, so reading it is
/// what seeds it.
final _provider = profileEditControllerProvider(_profile);

/// Makes one real edit, which is the state a
/// user is in when Save is live.
ProfileEditController _edited(ProviderContainer container) {
  final controller = container.read(_provider.notifier)
    ..editDisplayName('Updated Name');
  return controller;
}

/// Recording fake — counts reads and writes; the update outcome is injected.
final class _RecordingRepository implements ProfileRepository {
  _RecordingRepository({required this.updateResult});

  final Either<Failure, Profile> Function() updateResult;
  int fetchCalls = 0;
  int updateCalls = 0;

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() async {
    fetchCalls++;
    return right(_profile);
  }

  @override
  Future<Either<Failure, Profile>> updateMyProfile(ProfileEdit edit) async {
    updateCalls++;
    return updateResult();
  }

  @override
  Future<Either<Failure, Profile?>> fetchPublicProfile(String userId) async =>
      right(null);

  @override
  Future<Either<Failure, Unit>> setMyLayout(
    List<ProfileLayoutRow> rows,
  ) async => right(unit);
}

ProviderContainer _container(ProfileRepository repo) {
  final container = ProviderContainer(
    overrides: [profileRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  // Keep the auto-dispose controller alive across the awaits in submit.
  container.listen(_provider, (_, _) {});
  return container;
}

void main() {
  group('ProfileEditController.submit', () {
    test(
      'a successful save invalidates the read provider and sets saved',
      () async {
        final repo = _RecordingRepository(updateResult: () => right(_profile));
        final container = _container(repo);
        // Keep the read provider alive so the invalidation re-fetches.
        container.listen(profileProvider, (_, _) {});
        await container.read(profileProvider.future);
        expect(repo.fetchCalls, 1);

        await _edited(container).submit();

        final state = container.read(_provider);
        expect(state.saved, isTrue);
        expect(state.failure, isNull);
        expect(state.submitting, isFalse);

        // The read provider was invalidated, so the next read re-fetches.
        await container.read(profileProvider.future);
        expect(repo.fetchCalls, 2);
      },
    );

    test('an untouched form is not dirty, and Save has nothing to write', () {
      final repo = _RecordingRepository(updateResult: () => right(_profile));
      final container = _container(repo);

      expect(container.read(_provider).isDirty, isFalse);
    });

    test('editing a field and putting it back is not dirty either', () {
      final repo = _RecordingRepository(updateResult: () => right(_profile));
      final container = _container(repo);

      container.read(_provider.notifier)
        ..editDisplayName('Something else')
        ..editDisplayName(_profile.displayName);

      expect(container.read(_provider).isDirty, isFalse);
    });

    test('each editable field on its own makes the form dirty', () {
      for (final edit in <void Function(ProfileEditController)>[
        (c) => c.editDisplayName('Renamed'),
        (c) => c.editBio('A different bio'),
        (c) => c.selectTheme(ProfileTheme.frost),
        (c) => c.selectHeaderPlatform(Platform.wowRetail),
      ]) {
        final repo = _RecordingRepository(updateResult: () => right(_profile));
        final container = _container(repo);
        edit(container.read(_provider.notifier));

        expect(container.read(_provider).isDirty, isTrue);
      }
    });

    test('a client validation error does not call the backend', () async {
      final repo = _RecordingRepository(updateResult: () => right(_profile));
      final container = _container(repo);

      // Empty display name fails client validation before any backend call.
      final controller = container.read(_provider.notifier)
        ..editDisplayName('');
      await controller.submit();

      final state = container.read(_provider);
      expect(state.fieldErrors, isNotEmpty);
      expect(state.saved, isFalse);
      expect(repo.updateCalls, 0);
    });

    test('a backend Left carries the failure and does not set saved', () async {
      final repo = _RecordingRepository(
        updateResult: () => left(const InputFailure()),
      );
      final container = _container(repo);

      await _edited(container).submit();

      final state = container.read(_provider);
      expect(state.failure, isA<InputFailure>());
      expect(state.saved, isFalse);
      expect(state.submitting, isFalse);
    });
  });
}
