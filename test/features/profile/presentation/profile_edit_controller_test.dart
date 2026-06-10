import 'package:featgg/src/core/error/failure.dart';
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
  theme: ProfileTheme.classic,
  privacy: ProfilePrivacy.public,
  featuredPlatform: null,
);

const _validEdit = ProfileEdit(
  displayName: 'Updated Name',
  bio: 'Updated bio',
  theme: ProfileTheme.retro,
  privacy: ProfilePrivacy.private,
  featuredPlatform: null,
);

// Empty display name fails client validation before any backend call.
const _invalidEdit = ProfileEdit(
  displayName: '',
  bio: null,
  theme: ProfileTheme.classic,
  privacy: ProfilePrivacy.public,
  featuredPlatform: null,
);

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
}

ProviderContainer _container(ProfileRepository repo) {
  final container = ProviderContainer(
    overrides: [profileRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  // Keep the auto-dispose controller alive across the awaits in submit.
  container.listen(profileEditControllerProvider, (_, _) {});
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

        await container
            .read(profileEditControllerProvider.notifier)
            .submit(_validEdit);

        final state = container.read(profileEditControllerProvider);
        expect(state.saved, isTrue);
        expect(state.failure, isNull);
        expect(state.submitting, isFalse);

        // The read provider was invalidated, so the next read re-fetches.
        await container.read(profileProvider.future);
        expect(repo.fetchCalls, 2);
      },
    );

    test('a client validation error does not call the backend', () async {
      final repo = _RecordingRepository(updateResult: () => right(_profile));
      final container = _container(repo);

      await container
          .read(profileEditControllerProvider.notifier)
          .submit(_invalidEdit);

      final state = container.read(profileEditControllerProvider);
      expect(state.fieldErrors, isNotEmpty);
      expect(state.saved, isFalse);
      expect(repo.updateCalls, 0);
    });

    test('a backend Left carries the failure and does not set saved', () async {
      final repo = _RecordingRepository(
        updateResult: () => left(const InputFailure()),
      );
      final container = _container(repo);

      await container
          .read(profileEditControllerProvider.notifier)
          .submit(_validEdit);

      final state = container.read(profileEditControllerProvider);
      expect(state.failure, isA<InputFailure>());
      expect(state.saved, isFalse);
      expect(state.submitting, isFalse);
    });
  });
}
