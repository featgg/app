import 'dart:async';

import 'package:featgg/src/core/core.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/auth/domain/auth_domain.dart';
import 'package:featgg/src/features/profile/domain/profile_domain.dart';
import 'package:featgg/src/features/settings/presentation/settings_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

const _publicProfile = Profile(
  id: 'user-1',
  username: 'pub',
  displayName: 'Public User',
  avatarUrl: null,
  bio: null,
  theme: ProfileTheme.classic,
  privacy: ProfilePrivacy.public,
  featuredPlatform: null,
);

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
}

/// Recording auth fake: counts sign-out calls; the outcome is injected.
final class _RecordingAuthRepository implements AuthRepository {
  _RecordingAuthRepository({Either<Failure, Unit> Function()? signOutResult})
    : _signOutResult = signOutResult ?? (() => right(unit));

  final Either<Failure, Unit> Function() _signOutResult;
  int signOutCalls = 0;

  @override
  Future<Either<Failure, Unit>> signOut() async {
    signOutCalls++;
    return _signOutResult();
  }

  @override
  AuthStatus currentStatus() => AuthStatus.signedIn;

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

Widget _screen(ProfileRepository profileRepo, AuthRepository authRepo) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      profileRepositoryProvider.overrideWithValue(profileRepo),
      authRepositoryProvider.overrideWithValue(authRepo),
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
}
