import 'dart:async';

import 'package:featgg/src/core/core.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/auth/domain/auth_domain.dart';
import 'package:featgg/src/features/profile/domain/profile_domain.dart';
import 'package:featgg/src/features/settings/domain/account_deletion.dart';
import 'package:featgg/src/features/settings/domain/account_deletion_repository.dart';
import 'package:featgg/src/features/settings/domain/settings_providers.dart';
import 'package:featgg/src/features/settings/presentation/settings_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';

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

final _pendingProfile = Profile(
  id: 'user-1',
  username: 'pub',
  displayName: 'Public User',
  avatarUrl: null,
  bio: null,
  theme: ProfileTheme.crimson,
  privacy: ProfilePrivacy.public,
  featuredPlatform: null,
  deletionRequestedAt: DateTime.now().toUtc(),
);

/// Profile fake whose `fetchMyProfile` returns a pending profile until
/// [cleared] is set, then a cleared one. Driven by a flag rather than a call
/// sequence so the result is deterministic even though both the privacy seam
/// and the deletion-status seam read this same repository.
final class _ClearableProfileRepository implements ProfileRepository {
  bool cleared = false;

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() async =>
      right(cleared ? _publicProfile : _pendingProfile);

  @override
  Future<Either<Failure, Profile>> updateMyProfile(ProfileEdit edit) async =>
      right(_publicProfile);

  @override
  Future<Either<Failure, Profile?>> fetchPublicProfile(String userId) async =>
      right(null);

  @override
  Future<Either<Failure, Unit>> setMyLayout(
    List<ProfileLayoutRow> rows,
  ) async => right(unit);
}

/// Profile fake that starts non-pending and flips to pending once [scheduled]
/// is set — simulating a deletion scheduled inside the pushed delete-account
/// flow, observable only on a fresh read of the deletion-status seam.
final class _SchedulingProfileRepository implements ProfileRepository {
  bool scheduled = false;

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() async =>
      right(scheduled ? _pendingProfile : _publicProfile);

  @override
  Future<Either<Failure, Profile>> updateMyProfile(ProfileEdit edit) async =>
      right(_publicProfile);

  @override
  Future<Either<Failure, Profile?>> fetchPublicProfile(String userId) async =>
      right(null);

  @override
  Future<Either<Failure, Unit>> setMyLayout(
    List<ProfileLayoutRow> rows,
  ) async => right(unit);
}

/// Recording deletion-repo fake: counts cancel calls and, on cancel, clears the
/// linked profile fake so the post-invalidation re-read returns a cleared row.
final class _RecordingAccountDeletionRepository
    implements AccountDeletionRepository {
  _RecordingAccountDeletionRepository({this.onCancel});

  final void Function()? onCancel;
  int cancelCalls = 0;

  @override
  Future<Either<Failure, Unit>> cancelDeletion() async {
    cancelCalls++;
    onCancel?.call();
    return right(unit);
  }

  @override
  Future<Either<Failure, DeletionSchedule>> confirmDeletion(
    String code,
  ) async => right(DeletionSchedule(scheduledAt: DateTime.utc(2026)));

  @override
  Future<Either<Failure, Unit>> requestDeletion() async => right(unit);
}

/// Recording profile fake: captures the write and lets the update outcome be
/// injected.
final class _RecordingProfileRepository implements ProfileRepository {
  _RecordingProfileRepository({
    Either<Failure, Profile> Function()? updateResult,
  }) : _updateResult = updateResult ?? (() => right(_publicProfile));

  final Either<Failure, Profile> Function() _updateResult;
  int updateCalls = 0;
  ProfileEdit? lastEdit;

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() async =>
      right(_publicProfile);

  @override
  Future<Either<Failure, Profile>> updateMyProfile(ProfileEdit edit) async {
    updateCalls++;
    lastEdit = edit;
    return _updateResult();
  }

  @override
  Future<Either<Failure, Profile?>> fetchPublicProfile(String userId) async =>
      right(null);

  @override
  Future<Either<Failure, Unit>> setMyLayout(
    List<ProfileLayoutRow> rows,
  ) async => right(unit);
}

/// Recording auth fake: counts sign-out calls; the outcome is injected.
final class _RecordingAuthRepository implements AuthRepository {
  _RecordingAuthRepository({
    Either<Failure, Unit> Function()? signOutResult,
    AccountIdentity? identity,
  }) : _signOutResult = signOutResult ?? (() => right(unit)),
       _identity =
           identity ??
           const AccountIdentity(
             email: 'user@example.com',
             providerToken: 'email',
           );

  final Either<Failure, Unit> Function() _signOutResult;
  final AccountIdentity? _identity;
  int signOutCalls = 0;

  @override
  Future<Either<Failure, Unit>> signOut() async {
    signOutCalls++;
    return _signOutResult();
  }

  @override
  AuthStatus currentStatus() => AuthStatus.signedIn;

  @override
  AccountIdentity? currentIdentity() => _identity;

  @override
  Stream<AuthStatus> statusChanges() => const Stream.empty();

  @override
  Future<Either<Failure, Unit>> requestEmailCode(String email) async =>
      right(unit);

  @override
  Future<Either<Failure, Unit>> verifyEmailCode({
    required String email,
    required String code,
  }) async => right(unit);

  @override
  Future<Either<Failure, Unit>> signInWithOAuth(AuthProvider provider) async =>
      right(unit);
}

/// Auth fake whose sign-out never completes, so the in-flight (disabled) tile
/// state is observable; counts how many times sign-out was started.
final class _PendingSignOutAuthRepository implements AuthRepository {
  final _completer = Completer<Either<Failure, Unit>>();
  int signOutCalls = 0;

  @override
  Future<Either<Failure, Unit>> signOut() {
    signOutCalls++;
    return _completer.future;
  }

  @override
  AuthStatus currentStatus() => AuthStatus.signedIn;

  @override
  AccountIdentity? currentIdentity() =>
      const AccountIdentity(email: 'user@example.com', providerToken: 'email');

  @override
  Stream<AuthStatus> statusChanges() => const Stream.empty();

  @override
  Future<Either<Failure, Unit>> requestEmailCode(String email) async =>
      right(unit);

  @override
  Future<Either<Failure, Unit>> verifyEmailCode({
    required String email,
    required String code,
  }) async => right(unit);

  @override
  Future<Either<Failure, Unit>> signInWithOAuth(AuthProvider provider) async =>
      right(unit);
}

Widget _screen(
  ProfileRepository profileRepo,
  AuthRepository authRepo, {
  AccountDeletionRepository? deletionRepo,
}) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      profileRepositoryProvider.overrideWithValue(profileRepo),
      authRepositoryProvider.overrideWithValue(authRepo),
      accountDeletionRepositoryProvider.overrideWithValue(
        deletionRepo ?? _RecordingAccountDeletionRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SettingsScreen(),
    ),
  );
}

void main() {
  testWidgets('renders the privacy control and the sign-out action by key', (
    tester,
  ) async {
    await tester.pumpWidget(
      _screen(_RecordingProfileRepository(), _RecordingAuthRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settingsPrivacyToggle')), findsOneWidget);
    expect(find.byKey(const Key('settingsSignOutTile')), findsOneWidget);
    // The body is wrapped in SafeArea (architecture convention).
    expect(find.byType(SafeArea), findsWidgets);
  });

  testWidgets(
    'toggling privacy invokes the write path with the flipped value',
    (tester) async {
      final repo = _RecordingProfileRepository();
      await tester.pumpWidget(_screen(repo, _RecordingAuthRepository()));
      await tester.pumpAndSettle();

      // Seed profile is public, so the switch is off; tapping flips to private.
      await tester.tap(find.byKey(const Key('settingsPrivacyToggle')));
      await tester.pumpAndSettle();

      expect(repo.updateCalls, 1);
      expect(repo.lastEdit!.privacy, ProfilePrivacy.private);
    },
  );

  testWidgets('a privacy-write failure shows the error affordance', (
    tester,
  ) async {
    final repo = _RecordingProfileRepository(
      updateResult: () => left(const NetworkFailure()),
    );
    await tester.pumpWidget(_screen(repo, _RecordingAuthRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settingsPrivacyToggle')));
    await tester.pump(); // run setPrivacy
    await tester.pump(); // surface the error snackbar

    expect(
      find.byKey(const Key('settingsPrivacyErrorSnackBar')),
      findsOneWidget,
    );
  });

  testWidgets('tapping sign-out invokes signOut', (tester) async {
    final auth = _RecordingAuthRepository();
    await tester.pumpWidget(_screen(_RecordingProfileRepository(), auth));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settingsSignOutTile')));
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 1);
  });

  testWidgets('a second sign-out tap while one is in flight does not start a '
      'duplicate', (tester) async {
    final auth = _PendingSignOutAuthRepository();
    await tester.pumpWidget(_screen(_RecordingProfileRepository(), auth));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settingsSignOutTile')));
    await tester.pump(); // controller → AsyncLoading → tile disabled
    // The second tap lands on the now-disabled tile and must be a no-op.
    await tester.tap(
      find.byKey(const Key('settingsSignOutTile')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(auth.signOutCalls, 1);
  });

  testWidgets('identity rows render for a signed-in user', (tester) async {
    await tester.pumpWidget(
      _screen(
        _RecordingProfileRepository(),
        _RecordingAuthRepository(
          identity: const AccountIdentity(
            email: 'user@example.com',
            providerToken: 'google',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('accountSectionIdentityEmail')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('accountSectionIdentityProvider')),
      findsOneWidget,
    );
  });

  testWidgets('the banner is present when a deletion is pending', (
    tester,
  ) async {
    await tester.pumpWidget(
      _screen(_ClearableProfileRepository(), _RecordingAuthRepository()),
    );
    // The pending banner contains a CooldownCountdown periodic timer, so the
    // tree never quiesces; pump fixed frames instead of pumpAndSettle.
    await tester.pump(); // resolve the deletion-status future
    await tester.pump(); // render the banner

    expect(find.byKey(const Key('accountDeletionBanner')), findsOneWidget);
    expect(
      find.byKey(const Key('accountCancelDeletionButton')),
      findsOneWidget,
    );
    // The success snackbar must not fire on first render — only after a real
    // cancel — so the cancel controller's build must not pass through loading.
    expect(find.byKey(const Key('accountCancelSuccessSnackBar')), findsNothing);
  });

  testWidgets('the banner is absent when no deletion is pending', (
    tester,
  ) async {
    await tester.pumpWidget(
      _screen(_RecordingProfileRepository(), _RecordingAuthRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('accountDeletionBanner')), findsNothing);
    // No pending deletion: the delete-account tile stays enabled.
    expect(
      tester
          .widget<ListTile>(find.byKey(const Key('settingsDeleteAccountTile')))
          .enabled,
      isTrue,
    );
  });

  testWidgets(
    'the delete-account tile is disabled when a deletion is pending',
    (tester) async {
      await tester.pumpWidget(
        _screen(_ClearableProfileRepository(), _RecordingAuthRepository()),
      );
      // The pending banner's CooldownCountdown periodic timer keeps the tree
      // busy; pump fixed frames instead of pumpAndSettle.
      await tester.pump(); // resolve the deletion-status future
      await tester.pump(); // render with the pending state applied

      expect(
        tester
            .widget<ListTile>(
              find.byKey(const Key('settingsDeleteAccountTile')),
            )
            .enabled,
        isFalse,
      );
    },
  );

  testWidgets(
    'tapping Cancel invokes cancelDeletion and the refreshed read clears the '
    'banner',
    (tester) async {
      final profileRepo = _ClearableProfileRepository();
      // On cancel the deletion repo clears the profile fake, so the re-read the
      // controller triggers via invalidation returns a cleared row.
      final deletionRepo = _RecordingAccountDeletionRepository(
        onCancel: () => profileRepo.cleared = true,
      );
      await tester.pumpWidget(
        _screen(
          profileRepo,
          _RecordingAuthRepository(),
          deletionRepo: deletionRepo,
        ),
      );
      // CooldownCountdown's periodic timer keeps the tree busy; pump frames.
      await tester.pump(); // resolve the deletion-status future
      await tester.pump(); // render the banner
      expect(find.byKey(const Key('accountDeletionBanner')), findsOneWidget);

      await tester.tap(find.byKey(const Key('accountCancelDeletionButton')));
      await tester.pump(); // run cancel → invalidate the status read
      await tester.pump(); // re-read resolves to the cleared profile
      await tester.pump(); // banner removed

      expect(deletionRepo.cancelCalls, 1);
      expect(find.byKey(const Key('accountDeletionBanner')), findsNothing);
      expect(
        find.byKey(const Key('accountCancelSuccessSnackBar')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'returning from the delete-account flow refreshes the pending banner',
    (tester) async {
      final profileRepo = _SchedulingProfileRepository();
      final container = ProviderContainer(
        retry: (count, error) => null,
        overrides: [
          profileRepositoryProvider.overrideWithValue(profileRepo),
          authRepositoryProvider.overrideWithValue(_RecordingAuthRepository()),
          accountDeletionRepositoryProvider.overrideWithValue(
            _RecordingAccountDeletionRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
          GoRoute(
            path: '/settings/delete-account',
            builder: (_, _) =>
                const Scaffold(key: Key('stubDeleteAccountScreen')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No deletion is pending yet, so the banner is absent.
      expect(find.byKey(const Key('accountDeletionBanner')), findsNothing);

      // The user schedules a deletion inside the pushed delete-account flow.
      profileRepo.scheduled = true;
      await tester.tap(find.byKey(const Key('settingsDeleteAccountTile')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('stubDeleteAccountScreen')), findsOneWidget);

      // Returning invalidates the deletion-status read; the banner must surface
      // the now-pending state without a full screen rebuild.
      router.pop();
      await tester.pump(); // pop completes → invalidate fires
      await tester.pump(); // status re-read resolves
      await tester.pump(); // banner renders

      expect(find.byKey(const Key('accountDeletionBanner')), findsOneWidget);
    },
  );
}
