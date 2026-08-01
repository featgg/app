import 'dart:async';

import 'package:featgg/src/core/core.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/auth/domain/auth_domain.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/connections_repository.dart';
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

/// Recording deletion-repo fake: counts cancel calls and reports the pending
/// state from a mutable flag, so a test can flip it between reads (a deletion
/// scheduled elsewhere) and a cancel clears it for the post-invalidation
/// re-read.
final class _RecordingAccountDeletionRepository
    implements AccountDeletionRepository {
  _RecordingAccountDeletionRepository({this.pending = false});

  bool pending;
  int cancelCalls = 0;

  @override
  Future<Either<Failure, Unit>> cancelDeletion() async {
    cancelCalls++;
    pending = false;
    return right(unit);
  }

  @override
  Future<Either<Failure, DeletionSchedule>> confirmDeletion(
    String code,
  ) async => right(DeletionSchedule(scheduledAt: DateTime.utc(2026)));

  @override
  Future<Either<Failure, Unit>> requestDeletion() async => right(unit);

  @override
  Future<Either<Failure, DeletionStatus>> fetchDeletionStatus() async => right(
    DeletionStatus(requestedAt: pending ? DateTime.now().toUtc() : null),
  );
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

/// A connections repo whose linked set is the injected [platforms]. The feed
/// preview reads it to decide which platforms it can offer.
final class _FakeConnectionsRepository implements ConnectionsRepository {
  _FakeConnectionsRepository([this.platforms = const []]);

  final List<Platform> platforms;

  @override
  Future<Either<Failure, List<Connection>>> fetchMyConnections() async =>
      right([
        for (final platform in platforms)
          Connection(
            platform: platform,
            status: ConnectionStatus.active,
            createdAt: DateTime.utc(2024),
          ),
      ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Widget _screen(
  ProfileRepository profileRepo,
  AuthRepository authRepo, {
  AccountDeletionRepository? deletionRepo,
  List<Platform> linked = const [],
}) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      profileRepositoryProvider.overrideWithValue(profileRepo),
      authRepositoryProvider.overrideWithValue(authRepo),
      connectionsRepositoryProvider.overrideWithValue(
        _FakeConnectionsRepository(linked),
      ),
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
      _screen(
        _RecordingProfileRepository(),
        _RecordingAuthRepository(),
        deletionRepo: _RecordingAccountDeletionRepository(pending: true),
      ),
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
        _screen(
          _RecordingProfileRepository(),
          _RecordingAuthRepository(),
          deletionRepo: _RecordingAccountDeletionRepository(pending: true),
        ),
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
      // The cancel clears the pending flag, so the re-read the controller
      // triggers via invalidation reports no pending deletion.
      final deletionRepo = _RecordingAccountDeletionRepository(pending: true);
      await tester.pumpWidget(
        _screen(
          _RecordingProfileRepository(),
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
      final deletionRepo = _RecordingAccountDeletionRepository();
      final container = ProviderContainer(
        retry: (count, error) => null,
        overrides: [
          profileRepositoryProvider.overrideWithValue(
            _RecordingProfileRepository(),
          ),
          authRepositoryProvider.overrideWithValue(_RecordingAuthRepository()),
          accountDeletionRepositoryProvider.overrideWithValue(deletionRepo),
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
      deletionRepo.pending = true;
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

  testWidgets('feed preview: the tile shows the automatic choice when nothing '
      'is pinned', (tester) async {
    await tester.pumpWidget(
      _screen(
        _RecordingProfileRepository(),
        _RecordingAuthRepository(),
        linked: const [Platform.steam],
      ),
    );
    await tester.pumpAndSettle();

    final tile = tester.widget<ListTile>(
      find.byKey(const Key('settingsFeedPreviewTile')),
    );
    // The tile names the current choice, mirroring the privacy control: the
    // value is the title, what the control is is the subtitle.
    expect(
      (tile.title! as Text).data,
      _l10n(tester).profileFeaturedCardDefault,
    );
    expect(
      (tile.subtitle! as Text).data,
      _l10n(tester).settingsFeedPreviewLabel,
    );
  });

  testWidgets('feed preview: picking a platform writes it, preserving every '
      'other field', (tester) async {
    final repo = _RecordingProfileRepository();
    await tester.pumpWidget(
      _screen(
        repo,
        _RecordingAuthRepository(),
        linked: const [Platform.steam, Platform.chess],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settingsFeedPreviewTile')));
    await tester.pumpAndSettle();

    // Automatic plus one row per linked platform.
    expect(find.byKey(const Key('feedPreviewOption_default')), findsOneWidget);
    expect(find.byKey(const Key('feedPreviewOption_steam')), findsOneWidget);
    expect(find.byKey(const Key('feedPreviewOption_chess')), findsOneWidget);

    await tester.tap(find.byKey(const Key('feedPreviewOption_chess')));
    await tester.pumpAndSettle();

    expect(repo.updateCalls, 1);
    expect(repo.lastEdit!.featuredPlatform, Platform.chess);
    // Only the feed preview changes; the write carries the rest untouched.
    expect(repo.lastEdit!.displayName, _publicProfile.displayName);
    expect(repo.lastEdit!.privacy, _publicProfile.privacy);
    expect(repo.lastEdit!.theme, _publicProfile.theme);
    expect(repo.lastEdit!.headerPlatform, _publicProfile.headerPlatform);
  });

  testWidgets('feed preview: re-picking the current choice writes nothing', (
    tester,
  ) async {
    final repo = _RecordingProfileRepository();
    await tester.pumpWidget(
      _screen(repo, _RecordingAuthRepository(), linked: const [Platform.steam]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settingsFeedPreviewTile')));
    await tester.pumpAndSettle();
    // The profile pins nothing, so Automatic is the current choice.
    await tester.tap(find.byKey(const Key('feedPreviewOption_default')));
    await tester.pumpAndSettle();

    expect(repo.updateCalls, 0);
  });

  testWidgets('feed preview: dismissing the sheet writes nothing', (
    tester,
  ) async {
    final repo = _RecordingProfileRepository();
    await tester.pumpWidget(
      _screen(repo, _RecordingAuthRepository(), linked: const [Platform.steam]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settingsFeedPreviewTile')));
    await tester.pumpAndSettle();
    // A dismissal and an Automatic pick both resolve to a null platform; only
    // the pick may reach the write path.
    Navigator.of(
      tester.element(find.byKey(const Key('feedPreviewOption_steam'))),
    ).pop();
    await tester.pumpAndSettle();

    expect(repo.updateCalls, 0);
  });

  testWidgets('a profile write in flight disables every profile control, so '
      'two full-profile writes can never race', (tester) async {
    // Both controls write the WHOLE profile from their own snapshot. If the
    // second one's snapshot predates the first one's write, whichever lands
    // last silently reverts the other — privacy included.
    final repo = _PendingUpdateProfileRepository();
    await tester.pumpWidget(
      _screen(repo, _RecordingAuthRepository(), linked: const [Platform.steam]),
    );
    await tester.pumpAndSettle();

    // Start a privacy write and leave it hanging.
    await tester.tap(find.byKey(const Key('settingsPrivacyToggle')));
    await tester.pump();

    final toggle = tester.widget<SwitchListTile>(
      find.byKey(const Key('settingsPrivacyToggle')),
    );
    expect(toggle.onChanged, isNull);
    final tile = tester.widget<ListTile>(
      find.byKey(const Key('settingsFeedPreviewTile')),
    );
    expect(tile.enabled, isFalse);

    repo.updateGate.complete(right(_publicProfile));
    await tester.pumpAndSettle();
  });
}

/// A profile repo whose update never resolves until the test opens the gate,
/// so the in-flight window is observable.
final class _PendingUpdateProfileRepository implements ProfileRepository {
  final updateGate = Completer<Either<Failure, Profile>>();

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() async =>
      right(_publicProfile);

  @override
  Future<Either<Failure, Profile>> updateMyProfile(ProfileEdit edit) =>
      updateGate.future;

  @override
  Future<Either<Failure, Profile?>> fetchPublicProfile(String userId) async =>
      right(null);

  @override
  Future<Either<Failure, Unit>> setMyLayout(
    List<ProfileLayoutRow> rows,
  ) async => right(unit);
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(SettingsScreen)));
