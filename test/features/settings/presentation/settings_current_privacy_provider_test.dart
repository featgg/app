import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/profile/domain/profile_domain.dart';
import 'package:featgg/src/features/settings/presentation/settings_presentation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

const _publicProfile = Profile(
  id: 'user-1',
  username: 'pub',
  displayName: 'Public User',
  avatarUrl: null,
  bio: null,
  theme: ProfileTheme.crimson,
  privacy: ProfilePrivacy.public,
  featuredPlatform: null,
);

const _privateProfile = Profile(
  id: 'user-2',
  username: 'priv',
  displayName: 'Private User',
  avatarUrl: null,
  bio: null,
  theme: ProfileTheme.crimson,
  privacy: ProfilePrivacy.private,
  featuredPlatform: null,
);

/// Fake whose `fetchMyProfile` outcome is injected.
final class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository(this._fetchResult);

  final Either<Failure, Profile> Function() _fetchResult;
  int fetchCalls = 0;

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() async {
    fetchCalls++;
    return _fetchResult();
  }

  @override
  Future<Either<Failure, Profile>> updateMyProfile(ProfileEdit edit) async =>
      right(_publicProfile);

  @override
  Future<Either<Failure, Profile?>> fetchPublicProfile(String userId) async =>
      right(null);
}

ProviderContainer _container(ProfileRepository repo) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [profileRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('settingsCurrentPrivacyProvider', () {
    test('returns the current privacy on Right', () async {
      final container = _container(
        _FakeProfileRepository(() => right(_publicProfile)),
      );
      final privacy = await container.read(
        settingsCurrentPrivacyProvider.future,
      );
      expect(privacy, ProfilePrivacy.public);
    });

    test('reflects a private profile', () async {
      final container = _container(
        _FakeProfileRepository(() => right(_privateProfile)),
      );
      final privacy = await container.read(
        settingsCurrentPrivacyProvider.future,
      );
      expect(privacy, ProfilePrivacy.private);
    });

    test('surfaces a Failure as AsyncError on Left', () async {
      final container = _container(
        _FakeProfileRepository(() => left(const NetworkFailure())),
      );
      container.listen(settingsCurrentPrivacyProvider, (_, _) {});
      await expectLater(
        container.read(settingsCurrentPrivacyProvider.future),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('does not auto-retry on Left (its own _noRetry policy)', () async {
      final repo = _FakeProfileRepository(() => left(const NetworkFailure()));
      // No container-level retry override, so only the provider's own
      // `_noRetry` can suppress Riverpod's default retry.
      final container = ProviderContainer(
        overrides: [profileRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      container.read(settingsCurrentPrivacyProvider);
      await Future<void>.microtask(() {});
      await Future<void>.microtask(() {});

      expect(repo.fetchCalls, 1);
      expect(
        container.read(settingsCurrentPrivacyProvider),
        isA<AsyncError<ProfilePrivacy>>(),
      );
    });
  });
}
