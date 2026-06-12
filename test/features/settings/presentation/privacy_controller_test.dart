import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/profile/domain/profile_domain.dart';
import 'package:featgg/src/features/settings/presentation/settings_presentation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

// Seed with distinct non-privacy fields so the no-clobber assertion is
// meaningful: a privacy-only write must preserve every one of these.
const _seedProfile = Profile(
  id: 'user-1',
  username: 'seeduser',
  displayName: 'Seed Name',
  avatarUrl: null,
  bio: 'Seed bio',
  theme: ProfileTheme.retro,
  privacy: ProfilePrivacy.public,
  featuredPlatform: null,
);

/// Recording fake: counts reads/writes, captures the last edit, and lets each
/// test inject the fetch and update outcomes.
final class _RecordingProfileRepository implements ProfileRepository {
  _RecordingProfileRepository({
    Either<Failure, Profile> Function()? fetchResult,
    Either<Failure, Profile> Function()? updateResult,
  }) : _fetchResult = fetchResult ?? (() => right(_seedProfile)),
       _updateResult = updateResult ?? (() => right(_seedProfile));

  final Either<Failure, Profile> Function() _fetchResult;
  final Either<Failure, Profile> Function() _updateResult;
  int fetchCalls = 0;
  int updateCalls = 0;
  ProfileEdit? lastEdit;

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() async {
    fetchCalls++;
    return _fetchResult();
  }

  @override
  Future<Either<Failure, Profile>> updateMyProfile(ProfileEdit edit) async {
    updateCalls++;
    lastEdit = edit;
    return _updateResult();
  }

  @override
  Future<Either<Failure, Profile?>> fetchPublicProfile(String userId) async =>
      right(null);
}

ProviderContainer _container(ProfileRepository repo) {
  final container = ProviderContainer(
    // Disable Riverpod's automatic retry so error states are stable in tests.
    retry: (count, error) => null,
    overrides: [profileRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  // Keep the auto-dispose notifier alive across the awaits in setPrivacy.
  container.listen(privacyControllerProvider, (_, _) {});
  return container;
}

void main() {
  group('PrivacyController.setPrivacy', () {
    test('writes the new privacy, preserves every other field, and invalidates '
        'the settings read', () async {
      final repo = _RecordingProfileRepository();
      final container = _container(repo);
      // Keep the read seam alive so the post-write invalidation re-fetches.
      container.listen(settingsCurrentPrivacyProvider, (_, _) {});
      await container.read(settingsCurrentPrivacyProvider.future);
      final fetchesBefore = repo.fetchCalls;

      await container
          .read(privacyControllerProvider.notifier)
          .setPrivacy(ProfilePrivacy.private);

      // The write rides updateMyProfile, changing only privacy.
      expect(repo.updateCalls, 1);
      expect(repo.lastEdit!.privacy, ProfilePrivacy.private);
      // No-clobber: the other writable fields equal the seed.
      expect(repo.lastEdit!.displayName, _seedProfile.displayName);
      expect(repo.lastEdit!.bio, _seedProfile.bio);
      expect(repo.lastEdit!.theme, _seedProfile.theme);
      expect(repo.lastEdit!.featuredPlatform, _seedProfile.featuredPlatform);
      expect(container.read(privacyControllerProvider), isA<AsyncData<void>>());

      // Invalidation: re-reading the settings seam re-fetches (one fetch for
      // setPrivacy's own read, plus the invalidated re-read).
      await container.read(settingsCurrentPrivacyProvider.future);
      expect(repo.fetchCalls, greaterThan(fetchesBefore + 1));
    });

    test('a backend Left on the write surfaces the Failure and does not '
        'invalidate', () async {
      final repo = _RecordingProfileRepository(
        updateResult: () => left(const InputFailure()),
      );
      final container = _container(repo);
      container.listen(settingsCurrentPrivacyProvider, (_, _) {});
      await container.read(settingsCurrentPrivacyProvider.future);

      await container
          .read(privacyControllerProvider.notifier)
          .setPrivacy(ProfilePrivacy.private);

      expect(repo.updateCalls, 1);
      final state = container.read(privacyControllerProvider);
      expect(state, isA<AsyncError<void>>());
      expect(state.error, isA<InputFailure>());

      // Not invalidated: re-reading returns the cached value, no new fetch.
      final fetchesAfterWrite = repo.fetchCalls;
      await container.read(settingsCurrentPrivacyProvider.future);
      expect(repo.fetchCalls, fetchesAfterWrite);
    });

    test('a failed current-profile read surfaces the Failure and never '
        'writes', () async {
      final repo = _RecordingProfileRepository(
        fetchResult: () => left(const NetworkFailure()),
      );
      final container = _container(repo);

      await container
          .read(privacyControllerProvider.notifier)
          .setPrivacy(ProfilePrivacy.private);

      expect(repo.updateCalls, 0);
      final state = container.read(privacyControllerProvider);
      expect(state, isA<AsyncError<void>>());
      expect(state.error, isA<NetworkFailure>());
    });
  });
}
