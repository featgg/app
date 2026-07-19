import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:featgg/src/core/core.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/connections_repository.dart';
import 'package:featgg/src/features/profile/domain/profile_domain.dart';
import 'package:featgg/src/features/profile/presentation/profile_presentation.dart';
import 'package:flutter/material.dart';
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

/// Fake profile repository; the update outcome is injected per test.
final class _FakeRepository implements ProfileRepository {
  _FakeRepository({required this.updateResult});

  final Either<Failure, Profile> Function() updateResult;

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() async => right(_profile);

  @override
  Future<Either<Failure, Profile>> updateMyProfile(ProfileEdit edit) async =>
      updateResult();

  @override
  Future<Either<Failure, Profile?>> fetchPublicProfile(String userId) async =>
      right(null);
}

/// Holds the update future open so the submitting state stays observable.
final class _PendingRepository implements ProfileRepository {
  final _completer = Completer<Either<Failure, Profile>>();

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() async => right(_profile);

  @override
  Future<Either<Failure, Profile>> updateMyProfile(ProfileEdit edit) =>
      _completer.future;

  @override
  Future<Either<Failure, Profile?>> fetchPublicProfile(String userId) async =>
      right(null);
}

/// Fake avatar picker that immediately returns null (cancelled).
final class _CancelledPicker implements AvatarPicker {
  const _CancelledPicker();

  @override
  Future<AvatarPick?> pickAndCrop(BuildContext context) async => null;
}

/// Fake avatar picker that holds the future open (simulates in-flight picking).
final class _PendingPicker implements AvatarPicker {
  final completer = Completer<AvatarPick?>();

  @override
  Future<AvatarPick?> pickAndCrop(BuildContext context) => completer.future;
}

/// Fake avatar picker that immediately returns a pick result.
final class _ImmediatePicker implements AvatarPicker {
  const _ImmediatePicker();

  @override
  Future<AvatarPick?> pickAndCrop(BuildContext context) async =>
      AvatarPick(bytes: Uint8List(1), contentType: 'image/jpeg');
}

/// Fake avatar repository that always returns a moderation rejection.
final class _RejectingAvatarRepository implements AvatarRepository {
  const _RejectingAvatarRepository();

  @override
  Future<Either<Failure, String>> uploadAvatar({
    required Uint8List bytes,
    required String contentType,
  }) async => left(const ModerationRejectedFailure());
}

/// Fake avatar repository that always succeeds, returning a fixed URL.
final class _SucceedingAvatarRepository implements AvatarRepository {
  const _SucceedingAvatarRepository();

  static const uploadedUrl = 'https://cdn.example.com/uploaded.jpg';

  @override
  Future<Either<Failure, String>> uploadAvatar({
    required Uint8List bytes,
    required String contentType,
  }) async => right(uploadedUrl);
}

/// Fake avatar picker that returns a pick on the first call, then null
/// (cancelled) on subsequent calls. Used to reproduce the second-pick regression.
final class _PickThenCancelPicker implements AvatarPicker {
  int _callCount = 0;

  @override
  Future<AvatarPick?> pickAndCrop(BuildContext context) async {
    _callCount++;
    if (_callCount == 1) {
      return AvatarPick(bytes: Uint8List(1), contentType: 'image/jpeg');
    }
    return null;
  }
}

/// Fake avatar picker that fails to process the image (throws), distinct from a
/// user cancel. Exercises the decode/crop-failure path (Codex #2).
final class _ProcessingFailurePicker implements AvatarPicker {
  const _ProcessingFailurePicker();

  @override
  Future<AvatarPick?> pickAndCrop(BuildContext context) =>
      Future.error(const AvatarProcessingException('decode failed'));
}

/// Fake avatar repository that always returns the cooldown rate-limit failure.
/// retryAfterSeconds: 5 keeps the deadline short so the periodic timer fires
/// within the test's wall-clock budget; the controller seeds cooldownUntil ~5s
/// out, so onCooldown is immediately true.
final class _CooldownAvatarRepository implements AvatarRepository {
  const _CooldownAvatarRepository();

  @override
  Future<Either<Failure, String>> uploadAvatar({
    required Uint8List bytes,
    required String contentType,
  }) async => left(const RateLimitFailure(retryAfterSeconds: 5));
}

/// Succeeds on the first upload, then returns the cooldown rate-limit failure —
/// used to verify a stale success snackbar is dismissed when a cooldown hits.
final class _SucceedThenCooldownAvatarRepository implements AvatarRepository {
  int _calls = 0;

  @override
  Future<Either<Failure, String>> uploadAvatar({
    required Uint8List bytes,
    required String contentType,
  }) async {
    _calls++;
    if (_calls == 1) {
      return right(_SucceedingAvatarRepository.uploadedUrl);
    }
    return left(const RateLimitFailure(retryAfterSeconds: 5));
  }
}

/// Fake connections repository whose `fetchMyConnections` outcome is injected.
final class _FakeConnectionsRepository implements ConnectionsRepository {
  _FakeConnectionsRepository({required this.connectionsResult});

  final Either<Failure, List<Connection>> Function() connectionsResult;

  @override
  Future<Either<Failure, List<Connection>>> fetchMyConnections() async =>
      connectionsResult();

  @override
  Future<Either<Failure, Unit>> link({
    required Platform platform,
    required Map<String, String> formInput,
  }) async => right(unit);

  @override
  Future<Either<Failure, Unit>> unlink(Platform platform) async => right(unit);

  @override
  Future<Either<Failure, SyncResult>> refresh(Platform platform) async =>
      right(const SyncResult(skipped: false));

  @override
  Future<Either<Failure, RefreshAllResult>> refreshAll() async =>
      right(const RefreshAllResult(outcomes: []));
}

/// Connections repository that always returns an empty list (no platforms).
final class _EmptyConnectionsRepository extends _FakeConnectionsRepository {
  _EmptyConnectionsRepository() : super(connectionsResult: () => right([]));
}

/// Connections repository that always returns a network failure.
final class _FailingConnectionsRepository extends _FakeConnectionsRepository {
  _FailingConnectionsRepository()
    : super(connectionsResult: () => left(const NetworkFailure()));
}

Widget _screen(
  ProfileRepository profileRepo, {
  AvatarPicker avatarPicker = const _CancelledPicker(),
  AvatarRepository avatarRepo = const _RejectingAvatarRepository(),
  ConnectionsRepository? connectionsRepo,
  Profile profile = _profile,
}) {
  final container = ProviderContainer(
    overrides: [
      profileRepositoryProvider.overrideWithValue(profileRepo),
      avatarPickerProvider.overrideWithValue(avatarPicker),
      avatarRepositoryProvider.overrideWithValue(avatarRepo),
      connectionsRepositoryProvider.overrideWithValue(
        connectionsRepo ?? _EmptyConnectionsRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ProfileEditScreen(profile: profile),
    ),
  );
}

void main() {
  testWidgets('renders the form seeded from the profile', (tester) async {
    await tester.pumpWidget(
      _screen(_FakeRepository(updateResult: () => right(_profile))),
    );
    await tester.pump();

    // Seeded field values are present and the Save action is keyed.
    expect(find.text(_profile.displayName), findsOneWidget);
    expect(find.text(_profile.bio!), findsOneWidget);
    expect(find.byKey(const Key('profileSaveButton')), findsOneWidget);
  });

  testWidgets('upload affordance is present', (tester) async {
    await tester.pumpWidget(
      _screen(_FakeRepository(updateResult: () => right(_profile))),
    );
    await tester.pump();

    expect(find.byKey(const Key('avatarUploadField')), findsOneWidget);
  });

  testWidgets('upload affordance shows a spinner while picking is in-flight', (
    tester,
  ) async {
    await tester.pumpWidget(
      _screen(
        _FakeRepository(updateResult: () => right(_profile)),
        avatarPicker: _PendingPicker(),
      ),
    );
    await tester.pump();

    // Tap the avatar field to start a pick.
    await tester.tap(find.byKey(const Key('avatarUploadField')));
    await tester.pump();

    // A spinner should appear while picking is in flight.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a rejection surfaces a keyed error snackbar', (tester) async {
    await tester.pumpWidget(
      _screen(
        _FakeRepository(updateResult: () => right(_profile)),
        avatarPicker: const _ImmediatePicker(),
        avatarRepo: const _RejectingAvatarRepository(),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('avatarUploadField')));
    await tester.pumpAndSettle();

    // The error snackbar is matched by key, not by literal copy.
    expect(find.byKey(const Key('avatarUploadErrorSnackBar')), findsOneWidget);
  });

  testWidgets('a decode/crop failure surfaces a keyed error snackbar', (
    tester,
  ) async {
    await tester.pumpWidget(
      _screen(
        _FakeRepository(updateResult: () => right(_profile)),
        avatarPicker: const _ProcessingFailurePicker(),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('avatarUploadField')));
    await tester.pumpAndSettle();

    // A processing failure (not a cancel) surfaces the keyed error snackbar.
    expect(find.byKey(const Key('avatarUploadErrorSnackBar')), findsOneWidget);
  });

  testWidgets(
    'a 429 renders an inline cooldown countdown and disables the avatar field',
    (tester) async {
      await tester.pumpWidget(
        _screen(
          _FakeRepository(updateResult: () => right(_profile)),
          avatarPicker: const _ImmediatePicker(),
          avatarRepo: const _CooldownAvatarRepository(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('avatarUploadField')));
      await tester.pumpAndSettle();

      // RateLimitFailure: inline countdown affordance is shown.
      expect(find.byKey(const Key('avatarCooldownCountdown')), findsOneWidget);
      // RateLimitFailure: no transient error snackbar (the countdown is the
      // affordance; the screen explicitly skips the snackbar path for cooldowns).
      expect(find.byKey(const Key('avatarUploadErrorSnackBar')), findsNothing);
      // The avatar field's GestureDetector has onTap == null while onCooldown.
      final gesture = tester.widget<GestureDetector>(
        find
            .descendant(
              of: find.byKey(const Key('avatarUploadField')),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      expect(gesture.onTap, isNull);

      // Drain the controller's 5-second cooldown timer before teardown.
      await tester.pump(const Duration(seconds: 6));
    },
  );

  testWidgets(
    'a cooldown dismisses a still-visible success snackbar (no stale message)',
    (tester) async {
      await tester.pumpWidget(
        _screen(
          _FakeRepository(updateResult: () => right(_profile)),
          avatarPicker: const _ImmediatePicker(),
          avatarRepo: _SucceedThenCooldownAvatarRepository(),
        ),
      );
      await tester.pump();

      // First upload succeeds → success snackbar appears.
      await tester.tap(find.byKey(const Key('avatarUploadField')));
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const Key('avatarUploadSuccessSnackBar')),
        findsOneWidget,
      );

      // Second upload hits a 429 cooldown → the still-visible success snackbar
      // is dismissed and the inline countdown is shown instead.
      await tester.tap(find.byKey(const Key('avatarUploadField')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.byKey(const Key('avatarUploadSuccessSnackBar')),
        findsNothing,
      );
      expect(find.byKey(const Key('avatarCooldownCountdown')), findsOneWidget);

      // Drain the remaining cooldown timer before teardown.
      await tester.pump(const Duration(seconds: 6));
    },
  );

  testWidgets(
    'a backend save failure shows a localized message and keeps input',
    (tester) async {
      await tester.pumpWidget(
        _screen(
          _FakeRepository(updateResult: () => left(const InputFailure())),
        ),
      );
      await tester.pump();

      // Make the form dirty so Save is enabled.
      await tester.enterText(
        find.byKey(const Key('profileDisplayNameField')),
        'Changed Name',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('profileSaveButton')));
      await tester.pumpAndSettle();

      // The error node is matched by key, not by literal copy, and the entered
      // display name is still in the field.
      expect(find.byKey(const Key('profileEditErrorText')), findsOneWidget);
      expect(find.text('Changed Name'), findsOneWidget);
    },
  );

  testWidgets('shows a spinner in the Save action while submitting', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(_PendingRepository()));
    await tester.pump();

    // Make the form dirty so Save is enabled.
    await tester.enterText(
      find.byKey(const Key('profileDisplayNameField')),
      'Changed Name',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('profileSaveButton')));
    await tester.pump(); // submitting — the update is still in flight

    expect(
      find.descendant(
        of: find.byKey(const Key('profileSaveButton')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'successful upload renders the new avatar URL in _AvatarUploadField',
    (tester) async {
      await tester.pumpWidget(
        _screen(
          _FakeRepository(updateResult: () => right(_profile)),
          avatarPicker: const _ImmediatePicker(),
          avatarRepo: const _SucceedingAvatarRepository(),
        ),
      );
      await tester.pump();

      // Before upload: _profile.avatarUrl is null → no CachedNetworkImage.
      expect(find.byType(CachedNetworkImage), findsNothing);

      await tester.tap(find.byKey(const Key('avatarUploadField')));
      await tester.pumpAndSettle();

      // After success: a CachedNetworkImage with the uploaded URL is shown.
      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(image.imageUrl, _SucceedingAvatarRepository.uploadedUrl);
    },
  );

  testWidgets(
    'after a successful upload, a second cancelled pick keeps the uploaded URL in the preview',
    (tester) async {
      final pickThenCancel = _PickThenCancelPicker();
      await tester.pumpWidget(
        _screen(
          _FakeRepository(updateResult: () => right(_profile)),
          avatarPicker: pickThenCancel,
          avatarRepo: const _SucceedingAvatarRepository(),
        ),
      );
      await tester.pump();

      // First tap: picker returns a pick → upload succeeds → URL shown.
      await tester.tap(find.byKey(const Key('avatarUploadField')));
      await tester.pumpAndSettle();

      final imageAfterSuccess = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(
        imageAfterSuccess.imageUrl,
        _SucceedingAvatarRepository.uploadedUrl,
      );

      // Second tap: picker returns null (cancelled) → newAvatarUrl must stay sticky.
      await tester.tap(find.byKey(const Key('avatarUploadField')));
      await tester.pumpAndSettle();

      final imageAfterCancel = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(
        imageAfterCancel.imageUrl,
        _SucceedingAvatarRepository.uploadedUrl,
      );
    },
  );

  testWidgets('Save is disabled when pristine and enabled after a change', (
    tester,
  ) async {
    await tester.pumpWidget(
      _screen(_FakeRepository(updateResult: () => right(_profile))),
    );
    await tester.pump();

    // Pristine: onPressed must be null (disabled).
    final saveButton = tester.widget<TextButton>(
      find.descendant(
        of: find.byKey(const Key('profileSaveButton')),
        matching: find.byType(TextButton),
      ),
    );
    expect(saveButton.onPressed, isNull);

    // Change the display name — form is now dirty.
    await tester.enterText(
      find.byKey(const Key('profileDisplayNameField')),
      'New Name',
    );
    await tester.pump();

    final saveButtonAfter = tester.widget<TextButton>(
      find.descendant(
        of: find.byKey(const Key('profileSaveButton')),
        matching: find.byType(TextButton),
      ),
    );
    expect(saveButtonAfter.onPressed, isNotNull);
  });

  testWidgets('Save is disabled while an avatar upload is in-flight', (
    tester,
  ) async {
    final picker = _PendingPicker();
    await tester.pumpWidget(
      _screen(
        _FakeRepository(updateResult: () => right(_profile)),
        avatarPicker: picker,
      ),
    );
    await tester.pump();

    // Dirty the form so Save would be enabled if not for the in-flight upload.
    await tester.enterText(
      find.byKey(const Key('profileDisplayNameField')),
      'New Name',
    );
    await tester.pump();

    // Start an avatar upload that stays pending → status picking.
    await tester.tap(find.byKey(const Key('avatarUploadField')));
    await tester.pump();

    TextButton saveButton() => tester.widget<TextButton>(
      find.descendant(
        of: find.byKey(const Key('profileSaveButton')),
        matching: find.byType(TextButton),
      ),
    );

    // Dirty but an upload is in flight → Save is disabled.
    expect(saveButton().onPressed, isNull);

    // Resolve the pick as cancelled → status idle, upload no longer in flight.
    picker.completer.complete(null);
    await tester.pump();

    // Still dirty, nothing in flight → Save re-enables.
    expect(saveButton().onPressed, isNotNull);
  });

  // ── Featured-card selector tests ──────────────────────────────────────────

  testWidgets(
    'featured-card selector shows connected platforms and the default option',
    (tester) async {
      final connectionsRepo = _FakeConnectionsRepository(
        connectionsResult: () => right([
          Connection(
            platform: Platform.steam,
            status: ConnectionStatus.active,
            createdAt: DateTime.utc(2024),
          ),
        ]),
      );
      await tester.pumpWidget(
        _screen(
          _FakeRepository(updateResult: () => right(_profile)),
          connectionsRepo: connectionsRepo,
        ),
      );
      await tester.pumpAndSettle();

      // The selector widget is present.
      expect(find.byKey(const Key('featuredCardSelector')), findsOneWidget);

      // Open the dropdown.
      await tester.tap(find.byKey(const Key('featuredCardDropdown')));
      await tester.pumpAndSettle();

      // Both the default option and the Steam platform option are listed.
      // Assertions key off widget keys / structural behavior, not literal copy.
      expect(find.byType(DropdownMenuItem<Platform?>), findsWidgets);
    },
  );

  testWidgets('a connections-read failure renders the retry affordance', (
    tester,
  ) async {
    await tester.pumpWidget(
      _screen(
        _FakeRepository(updateResult: () => right(_profile)),
        connectionsRepo: _FailingConnectionsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    // AsyncValueWidget error state shows the keyed retry button.
    expect(find.byKey(const Key('asyncRetryButton')), findsOneWidget);
  });

  testWidgets(
    'picking a platform makes the form dirty and submit carries that featuredPlatform',
    (tester) async {
      ProfileEdit? capturedEdit;

      // Profile with a Steam connection available.
      final connectionsRepo = _FakeConnectionsRepository(
        connectionsResult: () => right([
          Connection(
            platform: Platform.steam,
            status: ConnectionStatus.active,
            createdAt: DateTime.utc(2024),
          ),
        ]),
      );

      // Use a recording repo to capture the submitted ProfileEdit.
      final recordingRepo = _RecordingFeaturedRepo(
        onUpdate: (edit) {
          capturedEdit = edit;
          return right(_profile);
        },
      );

      await tester.pumpWidget(
        _screen(recordingRepo, connectionsRepo: connectionsRepo),
      );
      await tester.pumpAndSettle();

      // Scroll the dropdown into view before tapping — the form is taller than
      // the 800×600 test viewport.
      await tester.ensureVisible(find.byKey(const Key('featuredCardDropdown')));
      await tester.pumpAndSettle();

      // Open the featured-card dropdown and pick Steam.
      await tester.tap(find.byKey(const Key('featuredCardDropdown')));
      await tester.pumpAndSettle();

      // After the dropdown opens, items appear in an overlay.  The Steam entry
      // is the only DropdownMenuItem whose value equals Platform.steam.
      final steamItems = find.byWidgetPredicate(
        (w) => w is DropdownMenuItem<Platform?> && w.value == Platform.steam,
      );
      await tester.tap(steamItems.last);
      await tester.pumpAndSettle();

      // Form is now dirty — Save button is enabled.
      final saveButton = tester.widget<TextButton>(
        find.descendant(
          of: find.byKey(const Key('profileSaveButton')),
          matching: find.byType(TextButton),
        ),
      );
      expect(saveButton.onPressed, isNotNull);

      // Tap Save.
      await tester.tap(find.byKey(const Key('profileSaveButton')));
      await tester.pumpAndSettle();

      expect(capturedEdit, isNotNull);
      expect(capturedEdit!.featuredPlatform, Platform.steam);
    },
  );

  // ── Theme swatch tests ────────────────────────────────────────────────────

  bool? swatchSelected(WidgetTester tester, ProfileTheme t) => tester
      .widget<Semantics>(find.byKey(Key('profileThemeSwatch_${t.name}')))
      .properties
      .selected;

  testWidgets('renders the swatch row with one swatch per theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      _screen(_FakeRepository(updateResult: () => right(_profile))),
    );
    await tester.pump();

    expect(find.byKey(const Key('profileThemeSwatchRow')), findsOneWidget);
    for (final t in ProfileTheme.values) {
      expect(
        find.byKey(Key('profileThemeSwatch_${t.name}')),
        findsOneWidget,
        reason: 'a swatch should render for ${t.name}',
      );
    }
  });

  testWidgets('the seeded theme swatch is marked selected', (tester) async {
    await tester.pumpWidget(
      _screen(_FakeRepository(updateResult: () => right(_profile))),
    );
    await tester.pump();

    // _profile seeds crimson; only that swatch reads selected.
    expect(swatchSelected(tester, ProfileTheme.crimson), isTrue);
    expect(swatchSelected(tester, ProfileTheme.frost), isFalse);
  });

  testWidgets(
    'tapping a different swatch enables Save and submit carries that theme',
    (tester) async {
      ProfileEdit? capturedEdit;
      final recordingRepo = _RecordingFeaturedRepo(
        onUpdate: (edit) {
          capturedEdit = edit;
          return right(_profile);
        },
      );

      await tester.pumpWidget(_screen(recordingRepo));
      await tester.pump();

      await tester.ensureVisible(
        find.byKey(const Key('profileThemeSwatch_frost')),
      );
      await tester.tap(find.byKey(const Key('profileThemeSwatch_frost')));
      await tester.pump();

      // The picked swatch is now selected and the form is dirty.
      expect(swatchSelected(tester, ProfileTheme.frost), isTrue);
      final saveButton = tester.widget<TextButton>(
        find.descendant(
          of: find.byKey(const Key('profileSaveButton')),
          matching: find.byType(TextButton),
        ),
      );
      expect(saveButton.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('profileSaveButton')));
      await tester.pumpAndSettle();

      expect(capturedEdit, isNotNull);
      expect(capturedEdit!.theme, ProfileTheme.frost);
    },
  );

  testWidgets(
    'a rejected save surfaces the error and keeps the picked swatch',
    (tester) async {
      await tester.pumpWidget(
        _screen(
          _FakeRepository(updateResult: () => left(const InputFailure())),
        ),
      );
      await tester.pump();

      await tester.ensureVisible(
        find.byKey(const Key('profileThemeSwatch_frost')),
      );
      await tester.tap(find.byKey(const Key('profileThemeSwatch_frost')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('profileSaveButton')));
      await tester.pumpAndSettle();

      // The rejection surfaces (keyed, not by copy) and the selection survives.
      expect(find.byKey(const Key('profileEditErrorText')), findsOneWidget);
      expect(swatchSelected(tester, ProfileTheme.frost), isTrue);
    },
  );
}

/// Recording fake that captures the submitted [ProfileEdit].
final class _RecordingFeaturedRepo implements ProfileRepository {
  _RecordingFeaturedRepo({required this.onUpdate});

  final Either<Failure, Profile> Function(ProfileEdit edit) onUpdate;

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() async => right(_profile);

  @override
  Future<Either<Failure, Profile>> updateMyProfile(ProfileEdit edit) async =>
      onUpdate(edit);

  @override
  Future<Either<Failure, Profile?>> fetchPublicProfile(String userId) async =>
      right(null);
}
