import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/profile/domain/profile_domain.dart';
import 'package:featgg/src/features/settings/presentation/settings_presentation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

Profile _profile({DateTime? deletionRequestedAt}) => Profile(
  id: 'user-1',
  username: 'user',
  displayName: 'User',
  avatarUrl: null,
  bio: null,
  theme: ProfileTheme.crimson,
  privacy: ProfilePrivacy.public,
  featuredPlatform: null,
  deletionRequestedAt: deletionRequestedAt,
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
      right(_profile());

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
    retry: (count, error) => null,
    overrides: [profileRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('settingsDeletionStatusProvider', () {
    test('folds a pending profile into a pending DeletionStatus', () async {
      final requestedAt = DateTime.utc(2026, 6, 12, 10);
      final container = _container(
        _FakeProfileRepository(
          () => right(_profile(deletionRequestedAt: requestedAt)),
        ),
      );

      final status = await container.read(
        settingsDeletionStatusProvider.future,
      );
      expect(status.isPending, isTrue);
      expect(status.scheduledAt, requestedAt.add(const Duration(days: 7)));
    });

    test('folds a non-pending profile into a non-pending status', () async {
      final container = _container(
        _FakeProfileRepository(() => right(_profile())),
      );

      final status = await container.read(
        settingsDeletionStatusProvider.future,
      );
      expect(status.isPending, isFalse);
      expect(status.scheduledAt, isNull);
    });

    test('surfaces a Failure as AsyncError on Left', () async {
      final container = _container(
        _FakeProfileRepository(() => left(const NetworkFailure())),
      );
      container.listen(settingsDeletionStatusProvider, (_, _) {});
      await expectLater(
        container.read(settingsDeletionStatusProvider.future),
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

      container.read(settingsDeletionStatusProvider);
      await Future<void>.microtask(() {});
      await Future<void>.microtask(() {});

      expect(repo.fetchCalls, 1);
      expect(
        container.read(settingsDeletionStatusProvider),
        isA<AsyncError<DeletionStatus>>(),
      );
    });
  });
}
