import 'dart:async';
import 'dart:typed_data';

import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/observability/observability.dart';
import 'package:featgg/src/features/profile/domain/profile_domain.dart';
import 'package:featgg/src/features/profile/presentation/profile_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Records every reportError call so tests can assert on reporting behaviour.
final class _RecordingReporter implements CrashReporter {
  final List<Object> reported = [];

  @override
  Future<void> reportError(Object error, StackTrace? stackTrace) async {
    reported.add(error);
  }
}

final class _CancelledPicker implements AvatarPicker {
  const _CancelledPicker();

  @override
  Future<AvatarPick?> pickAndCrop(BuildContext context) async => null;
}

final class _ImmediatePicker implements AvatarPicker {
  const _ImmediatePicker();

  @override
  Future<AvatarPick?> pickAndCrop(BuildContext context) async =>
      AvatarPick(bytes: Uint8List(1), contentType: 'image/jpeg');
}

final class _PendingPicker implements AvatarPicker {
  final completer = Completer<AvatarPick?>();

  @override
  Future<AvatarPick?> pickAndCrop(BuildContext context) => completer.future;
}

final class _ThrowingPicker implements AvatarPicker {
  const _ThrowingPicker();

  @override
  Future<AvatarPick?> pickAndCrop(BuildContext context) =>
      Future.error(Exception('photo permission denied'));
}

/// Picker whose future throws [AvatarProcessingException] after the completer
/// is resolved externally. Used to test the Codex #1 disposed-catch guard.
final class _ErrorPendingPicker implements AvatarPicker {
  final completer = Completer<AvatarPick?>();

  @override
  Future<AvatarPick?> pickAndCrop(BuildContext context) async {
    await completer.future;
    throw const AvatarProcessingException('decode failed');
  }
}

/// Picker that immediately throws [AvatarProcessingException].
final class _ProcessingFailurePicker implements AvatarPicker {
  const _ProcessingFailurePicker();

  @override
  Future<AvatarPick?> pickAndCrop(BuildContext context) =>
      Future.error(const AvatarProcessingException('decode failed'));
}

final class _SuccessRepository implements AvatarRepository {
  const _SuccessRepository();

  @override
  Future<Either<Failure, String>> uploadAvatar({
    required Uint8List bytes,
    required String contentType,
  }) async => right('https://cdn.example.com/new.jpg');
}

final class _FailingRepository implements AvatarRepository {
  const _FailingRepository(this.failure);

  final Failure failure;

  @override
  Future<Either<Failure, String>> uploadAvatar({
    required Uint8List bytes,
    required String contentType,
  }) async => left(failure);
}

const _profile = Profile(
  id: 'user-1',
  username: 'testuser',
  displayName: 'Test User',
  avatarUrl: null,
  bio: null,
  theme: ProfileTheme.classic,
  privacy: ProfilePrivacy.public,
);

/// Counts reads so the success test can observe `profileProvider` invalidation
/// as a re-fetch (mirrors the read-provider-invalidation assertion in
/// `profile_edit_controller_test.dart`).
final class _CountingProfileRepository implements ProfileRepository {
  int fetchCalls = 0;

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() async {
    fetchCalls++;
    return right(_profile);
  }

  @override
  Future<Either<Failure, Profile>> updateMyProfile(ProfileEdit edit) async =>
      right(_profile);
}

// ---------------------------------------------------------------------------
// Scaffold — pumps a ProviderScope and keeps the auto-dispose controller alive.
// ---------------------------------------------------------------------------

Future<(ProviderContainer, BuildContext, _RecordingReporter)> _pump(
  WidgetTester tester, {
  required AvatarPicker picker,
  required AvatarRepository avatarRepo,
  ProfileRepository? profileRepo,
  _RecordingReporter? crashReporter,
}) async {
  final reporter = crashReporter ?? _RecordingReporter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        avatarPickerProvider.overrideWithValue(picker),
        avatarRepositoryProvider.overrideWithValue(avatarRepo),
        crashReporterProvider.overrideWithValue(reporter),
        if (profileRepo != null)
          profileRepositoryProvider.overrideWithValue(profileRepo),
      ],
      child: const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    ),
  );
  final ctx = tester.element(find.byType(Scaffold));
  final container = ProviderScope.containerOf(ctx);
  // Without a retained listener the auto-dispose controller is recycled between
  // awaits/pumps and build() resets it to idle.
  container.listen(avatarUploadControllerProvider, (_, _) {});
  return (container, ctx, reporter);
}

void main() {
  testWidgets('cancelled pick → stays idle, no upload', (tester) async {
    final (container, ctx, _) = await _pump(
      tester,
      picker: const _CancelledPicker(),
      avatarRepo: const _SuccessRepository(),
    );

    await container
        .read(avatarUploadControllerProvider.notifier)
        .pickAndUpload(ctx);

    expect(
      container.read(avatarUploadControllerProvider).status,
      AvatarUploadStatus.idle,
    );
  });

  testWidgets(
    'successful upload → status success, profileProvider invalidated',
    (tester) async {
      final profileRepo = _CountingProfileRepository();
      final (container, ctx, _) = await _pump(
        tester,
        picker: const _ImmediatePicker(),
        avatarRepo: const _SuccessRepository(),
        profileRepo: profileRepo,
      );
      container.listen(profileProvider, (_, _) {});
      await container.read(profileProvider.future);
      expect(profileRepo.fetchCalls, 1);

      await container
          .read(avatarUploadControllerProvider.notifier)
          .pickAndUpload(ctx);

      final successState = container.read(avatarUploadControllerProvider);
      expect(successState.status, AvatarUploadStatus.success);
      expect(successState.newAvatarUrl, 'https://cdn.example.com/new.jpg');
      // Invalidation forces the next read to re-fetch.
      await container.read(profileProvider.future);
      expect(profileRepo.fetchCalls, 2);
    },
  );

  testWidgets('upload failure → status error carrying the Failure', (
    tester,
  ) async {
    const failure = ModerationRejectedFailure(categories: ['sexual']);
    final (container, ctx, _) = await _pump(
      tester,
      picker: const _ImmediatePicker(),
      avatarRepo: const _FailingRepository(failure),
    );

    await container
        .read(avatarUploadControllerProvider.notifier)
        .pickAndUpload(ctx);

    final state = container.read(avatarUploadControllerProvider);
    expect(state.status, AvatarUploadStatus.error);
    expect(state.failure, isA<ModerationRejectedFailure>());
  });

  testWidgets('in-flight: status is picking while the picker is pending', (
    tester,
  ) async {
    final pendingPicker = _PendingPicker();
    final (container, ctx, _) = await _pump(
      tester,
      picker: pendingPicker,
      avatarRepo: const _SuccessRepository(),
    );

    // Do not await — keep the future in-flight at the pick step.
    unawaited(
      container
          .read(avatarUploadControllerProvider.notifier)
          .pickAndUpload(ctx),
    );
    await tester.pump();

    expect(
      container.read(avatarUploadControllerProvider).status,
      AvatarUploadStatus.picking,
    );

    // Let the pending pick resolve (cancelled) so nothing dangles.
    pendingPicker.completer.complete(null);
    await tester.pump();
  });

  testWidgets(
    'throwing picker → status error carrying UnexpectedFailure, not stuck at picking',
    (tester) async {
      final (container, ctx, _) = await _pump(
        tester,
        picker: const _ThrowingPicker(),
        avatarRepo: const _SuccessRepository(),
      );

      await container
          .read(avatarUploadControllerProvider.notifier)
          .pickAndUpload(ctx);

      final state = container.read(avatarUploadControllerProvider);
      expect(state.status, AvatarUploadStatus.error);
      expect(state.failure, isA<UnexpectedFailure>());
    },
  );

  testWidgets('disposal mid-flight → no throw, no state write after disposal', (
    tester,
  ) async {
    // A fresh disposable container (NOT _pump) so auto-dispose actually fires.
    final pendingPicker = _PendingPicker();
    final disposeContainer = ProviderContainer(
      overrides: [
        avatarPickerProvider.overrideWithValue(pendingPicker),
        avatarRepositoryProvider.overrideWithValue(const _SuccessRepository()),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: disposeContainer,
        child: const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      ),
    );
    final ctx = tester.element(find.byType(Scaffold));

    // Start the pick pipeline without awaiting; the picker future is pending.
    final future = disposeContainer
        .read(avatarUploadControllerProvider.notifier)
        .pickAndUpload(ctx);

    await tester.pump(); // controller is now at picking

    // Dispose the container while the picker future is still pending.
    disposeContainer.dispose();

    // Complete the picker AFTER disposal; the guard must silently return.
    pendingPicker.completer.complete(
      AvatarPick(bytes: Uint8List(1), contentType: 'image/jpeg'),
    );

    // The future must resolve without throwing (no UnmountedRefException).
    await expectLater(future, completes);
  });

  testWidgets('RateLimitFailure → status cooldown, seeds seconds', (
    tester,
  ) async {
    final (container, ctx, _) = await _pump(
      tester,
      picker: const _ImmediatePicker(),
      avatarRepo: const _FailingRepository(
        RateLimitFailure(retryAfterSeconds: 30),
      ),
    );

    await container
        .read(avatarUploadControllerProvider.notifier)
        .pickAndUpload(ctx);

    final state = container.read(avatarUploadControllerProvider);
    expect(state.status, AvatarUploadStatus.cooldown);
    expect(state.failure, isA<RateLimitFailure>());
    expect(state.cooldownSecondsRemaining, 30);
  });

  testWidgets('cooldown elapses → returns to idle at retry_after window', (
    tester,
  ) async {
    final (container, ctx, _) = await _pump(
      tester,
      picker: const _ImmediatePicker(),
      avatarRepo: const _FailingRepository(
        RateLimitFailure(retryAfterSeconds: 30),
      ),
    );

    await container
        .read(avatarUploadControllerProvider.notifier)
        .pickAndUpload(ctx);
    expect(
      container.read(avatarUploadControllerProvider).status,
      AvatarUploadStatus.cooldown,
    );

    // The window equals retry_after (30 s) — still cooldown just before it.
    await tester.pump(const Duration(seconds: 29));
    expect(
      container.read(avatarUploadControllerProvider).status,
      AvatarUploadStatus.cooldown,
    );

    // Cross the window; the Timer fires → idle.
    await tester.pump(const Duration(seconds: 2));
    expect(
      container.read(avatarUploadControllerProvider).status,
      AvatarUploadStatus.idle,
    );
  });

  testWidgets('absent retry_after → falls back to ~60s window', (tester) async {
    final (container, ctx, _) = await _pump(
      tester,
      picker: const _ImmediatePicker(),
      avatarRepo: const _FailingRepository(RateLimitFailure()),
    );

    await container
        .read(avatarUploadControllerProvider.notifier)
        .pickAndUpload(ctx);
    expect(
      container.read(avatarUploadControllerProvider).status,
      AvatarUploadStatus.cooldown,
    );

    // Still cooldown just before the 60 s fallback window.
    await tester.pump(const Duration(seconds: 59));
    expect(
      container.read(avatarUploadControllerProvider).status,
      AvatarUploadStatus.cooldown,
    );

    // Cross the fallback window; the Timer fires → idle.
    await tester.pump(const Duration(seconds: 2));
    expect(
      container.read(avatarUploadControllerProvider).status,
      AvatarUploadStatus.idle,
    );
  });

  testWidgets(
    'decode/crop failure → status error, MediaProcessingFailure, not idle',
    (tester) async {
      final (container, ctx, reporter) = await _pump(
        tester,
        picker: const _ProcessingFailurePicker(),
        avatarRepo: const _SuccessRepository(),
      );

      await container
          .read(avatarUploadControllerProvider.notifier)
          .pickAndUpload(ctx);

      final state = container.read(avatarUploadControllerProvider);
      expect(state.status, AvatarUploadStatus.error);
      expect(state.failure, isA<MediaProcessingFailure>());
      expect(reporter.reported, isEmpty);
    },
  );

  testWidgets(
    'dispose during a THROWING pick → no throw, no post-dispose write',
    (tester) async {
      // Uses _ErrorPendingPicker: completer resolves first, then the picker
      // throws AvatarProcessingException — exercises the catch guard (Codex #1).
      final errorPicker = _ErrorPendingPicker();
      final disposeContainer = ProviderContainer(
        overrides: [
          avatarPickerProvider.overrideWithValue(errorPicker),
          avatarRepositoryProvider.overrideWithValue(
            const _SuccessRepository(),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: disposeContainer,
          child: const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
        ),
      );
      final ctx = tester.element(find.byType(Scaffold));

      final future = disposeContainer
          .read(avatarUploadControllerProvider.notifier)
          .pickAndUpload(ctx);

      await tester.pump(); // controller is at picking

      // Dispose before the picker completes.
      disposeContainer.dispose();

      // Completing the completer causes pickAndCrop to throw
      // AvatarProcessingException AFTER disposal — the catch guard must
      // silently return without writing state.
      errorPicker.completer.complete(null);

      await expectLater(future, completes);
    },
  );

  testWidgets(
    'unexpected picker fault → UnexpectedFailure AND crash-reported once',
    (tester) async {
      final (container, ctx, reporter) = await _pump(
        tester,
        picker: const _ThrowingPicker(),
        avatarRepo: const _SuccessRepository(),
      );

      await container
          .read(avatarUploadControllerProvider.notifier)
          .pickAndUpload(ctx);

      final state = container.read(avatarUploadControllerProvider);
      expect(state.status, AvatarUploadStatus.error);
      expect(state.failure, isA<UnexpectedFailure>());
      expect(reporter.reported, hasLength(1));
    },
  );

  testWidgets(
    'AvatarProcessingException → MediaProcessingFailure AND NOT crash-reported',
    (tester) async {
      final (container, ctx, reporter) = await _pump(
        tester,
        picker: const _ProcessingFailurePicker(),
        avatarRepo: const _SuccessRepository(),
      );

      await container
          .read(avatarUploadControllerProvider.notifier)
          .pickAndUpload(ctx);

      final state = container.read(avatarUploadControllerProvider);
      expect(state.status, AvatarUploadStatus.error);
      expect(state.failure, isA<MediaProcessingFailure>());
      expect(reporter.reported, isEmpty);
    },
  );
}
