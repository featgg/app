import 'dart:async';

import 'package:featgg/src/core/core.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/auth/domain/auth_domain.dart';
import 'package:featgg/src/features/auth/presentation/auth_presentation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Repository whose request/verify outcomes are injected per test.
final class _FakeRepository implements AuthRepository {
  _FakeRepository({
    Either<Failure, Unit>? requestResult,
    Either<Failure, Unit>? verifyResult,
  }) : _requestResult = requestResult ?? right(unit),
       _verifyResult = verifyResult ?? right(unit);

  final Either<Failure, Unit> _requestResult;
  final Either<Failure, Unit> _verifyResult;

  @override
  Future<Either<Failure, Unit>> requestEmailCode(String email) async =>
      _requestResult;

  @override
  Future<Either<Failure, Unit>> verifyEmailCode({
    required String email,
    required String code,
  }) async => _verifyResult;

  @override
  Future<Either<Failure, Unit>> signOut() async => right(unit);

  @override
  AuthStatus currentStatus() => AuthStatus.signedOut;

  @override
  Stream<AuthStatus> statusChanges() => const Stream.empty();
}

/// Counts how many times requestEmailCode was called.
final class _CountingRepository implements AuthRepository {
  int requestCount = 0;
  int verifyCount = 0;
  final Either<Failure, Unit> requestResult;

  _CountingRepository({Either<Failure, Unit>? requestResult})
    : requestResult = requestResult ?? right(unit);

  @override
  Future<Either<Failure, Unit>> requestEmailCode(String email) async {
    requestCount++;
    return requestResult;
  }

  @override
  Future<Either<Failure, Unit>> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    verifyCount++;
    return right(unit);
  }

  @override
  Future<Either<Failure, Unit>> signOut() async => right(unit);

  @override
  AuthStatus currentStatus() => AuthStatus.signedOut;

  @override
  Stream<AuthStatus> statusChanges() => const Stream.empty();
}

/// Succeeds on the first request then rate-limits all subsequent calls.
final class _FirstSuccessThenRateLimitRepository implements AuthRepository {
  int _requestCount = 0;

  @override
  Future<Either<Failure, Unit>> requestEmailCode(String email) async {
    _requestCount++;
    return _requestCount == 1
        ? right(unit)
        : left(const AuthRateLimitFailure());
  }

  @override
  Future<Either<Failure, Unit>> verifyEmailCode({
    required String email,
    required String code,
  }) async => right(unit);

  @override
  Future<Either<Failure, Unit>> signOut() async => right(unit);

  @override
  AuthStatus currentStatus() => AuthStatus.signedOut;

  @override
  Stream<AuthStatus> statusChanges() => const Stream.empty();
}

/// Holds the request future open so the in-flight (submitting) state is
/// observable in a widget test.
final class _PendingRepository implements AuthRepository {
  final requestCompleter = Completer<Either<Failure, Unit>>();

  @override
  Future<Either<Failure, Unit>> requestEmailCode(String email) =>
      requestCompleter.future;

  @override
  Future<Either<Failure, Unit>> verifyEmailCode({
    required String email,
    required String code,
  }) async => right(unit);

  @override
  Future<Either<Failure, Unit>> signOut() async => right(unit);

  @override
  AuthStatus currentStatus() => AuthStatus.signedOut;

  @override
  Stream<AuthStatus> statusChanges() => const Stream.empty();
}

Widget _screen(AuthRepository repo) {
  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SignInScreen(),
    ),
  );
}

void main() {
  testWidgets('send disables while rate-limited, re-enables after cooldown', (
    tester,
  ) async {
    await tester.pumpWidget(
      _screen(
        _FakeRepository(requestResult: left(const AuthRateLimitFailure())),
      ),
    );
    await tester.pumpAndSettle();

    final sendButton = find.byType(FilledButton);
    expect(tester.widget<FilledButton>(sendButton).onPressed, isNotNull);

    await tester.enterText(find.byType(TextFormField), 'user@example.com');
    await tester.tap(sendButton);
    await tester.pumpAndSettle();

    // Rate-limited: the send action is disabled so the user backs off.
    expect(tester.widget<FilledButton>(sendButton).onPressed, isNull);

    // After the cooldown elapses the send action re-enables.
    await tester.pump(const Duration(seconds: 61));
    expect(tester.widget<FilledButton>(sendButton).onPressed, isNotNull);
  });

  testWidgets('verify disables while rate-limited, re-enables after cooldown', (
    tester,
  ) async {
    await tester.pumpWidget(
      _screen(
        _FakeRepository(verifyResult: left(const AuthRateLimitFailure())),
      ),
    );
    await tester.pumpAndSettle();

    // Email step: a successful send advances to the code step.
    await tester.enterText(find.byType(TextFormField), 'user@example.com');
    await tester.tap(find.byType(FilledButton));
    // Use pump(Duration) while the proactive display ticker may be live.
    await tester.pump(const Duration(milliseconds: 100));

    // Code step: enter the code and tap Verify (rate-limited).
    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.pump();
    final verifyButton = find.byType(FilledButton);
    expect(tester.widget<FilledButton>(verifyButton).onPressed, isNotNull);

    await tester.tap(verifyButton);
    await tester.pump();
    expect(tester.widget<FilledButton>(verifyButton).onPressed, isNull);

    // The verify cooldown clears after the reactive window; the same code is
    // submittable again (no identical-code guard).
    await tester.pump(const Duration(seconds: 61));
    expect(tester.widget<FilledButton>(verifyButton).onPressed, isNotNull);
  });

  testWidgets(
    'primary button shows a spinner and is disabled while submitting',
    (tester) async {
      // Force Material so `.adaptive` renders a CircularProgressIndicator.
      // Reset inside the body (not addTearDown) — the framework's debug-var
      // invariant check runs before teardown callbacks.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final repo = _PendingRepository();
        await tester.pumpWidget(_screen(repo));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), 'user@example.com');
        await tester.tap(find.byType(FilledButton));
        await tester.pump(); // apply submitting: true

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );

        repo.requestCompleter.complete(right(unit));
        // Use pump(Duration) while the proactive display ticker may be live.
        await tester.pump(const Duration(milliseconds: 100));

        // Advanced to the code step; the in-flight spinner is gone.
        expect(find.byType(CircularProgressIndicator), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'email-format gate: malformed email does not call requestEmailCode',
    (tester) async {
      final repo = _CountingRepository();
      await tester.pumpWidget(_screen(repo));
      await tester.pumpAndSettle();

      // Tap Continue with a malformed email — should NOT advance.
      await tester.enterText(find.byType(TextFormField), '123');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(repo.requestCount, 0);
      // Still on the email step (only one FormField visible).
      expect(find.byType(FilledButton), findsOneWidget);

      // Enter a valid email — should call requestEmailCode once and advance.
      await tester.enterText(find.byType(TextFormField), 'user@example.com');
      await tester.tap(find.byType(FilledButton));
      await tester.pump(const Duration(milliseconds: 100));

      expect(repo.requestCount, 1);
    },
  );

  testWidgets(
    'resend starts disabled with countdown; Verify is independent of resend',
    (tester) async {
      await tester.pumpWidget(_screen(_FakeRepository()));
      await tester.pumpAndSettle();

      // Send succeeds → code step.
      await tester.enterText(find.byType(TextFormField), 'user@example.com');
      await tester.tap(find.byType(FilledButton));
      await tester.pump(const Duration(milliseconds: 100));

      // Resend TextButton is disabled immediately after a successful send.
      final resendButton = find.byType(TextButton).first;
      expect(tester.widget<TextButton>(resendButton).onPressed, isNull);

      // Verify is NOT gated by the resend countdown — with 6 digits it enables.
      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );

      // The proactive interval mirrors the server's resend window; once it
      // elapses, Resend re-enables.
      await tester.pump(const Duration(seconds: 61));
      expect(tester.widget<TextButton>(resendButton).onPressed, isNotNull);
    },
  );

  testWidgets('a successful resend shows a transient confirmation snackbar', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(_FakeRepository()));
    await tester.pumpAndSettle();

    // Send succeeds → code step.
    await tester.enterText(find.byType(TextFormField), 'user@example.com');
    await tester.tap(find.byType(FilledButton));
    await tester.pump(const Duration(milliseconds: 100));

    // No snackbar on the initial send — the step change is its feedback.
    expect(find.byType(SnackBar), findsNothing);

    // Let the resend window elapse, then resend.
    final resendButton = find.byType(TextButton).first;
    await tester.pump(const Duration(seconds: 61));
    await tester.tap(resendButton);
    // Use pump(Duration) — the re-seeded display ticker is live, so the tree
    // never settles. Assert by widget type, not localized copy.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SnackBar), findsOneWidget);

    // Drain the re-seeded resend ticker and the snackbar's auto-dismiss timer
    // so nothing is pending at teardown.
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('Change email is disabled during send cooldown (bypass closed)', (
    tester,
  ) async {
    final repo = _FirstSuccessThenRateLimitRepository();
    await tester.pumpWidget(_screen(repo));
    await tester.pumpAndSettle();

    // First request succeeds → advance to code step.
    await tester.enterText(find.byType(TextFormField), 'user@example.com');
    await tester.tap(find.byType(FilledButton));
    await tester.pump(const Duration(milliseconds: 100));

    // Tap Resend (second request → rate-limited → sendCooldownActive).
    final resendButton = find.byType(TextButton).first;
    // Advance past the proactive window so Resend is available.
    await tester.pump(const Duration(seconds: 61));
    expect(tester.widget<TextButton>(resendButton).onPressed, isNotNull);
    await tester.tap(resendButton);
    await tester.pump();

    // After the resend 429, sendCooldownActive is true.
    // The "Change email" button (second TextButton) must be disabled.
    final changeEmailButton = find.byType(TextButton).last;
    expect(tester.widget<TextButton>(changeEmailButton).onPressed, isNull);

    // After the reactive cooldown clears, Change email re-enables.
    await tester.pump(const Duration(seconds: 61));
    expect(tester.widget<TextButton>(changeEmailButton).onPressed, isNotNull);
  });

  testWidgets(
    'a successful resend restarts the countdown (cannot be hammered)',
    (tester) async {
      await tester.pumpWidget(_screen(_FakeRepository()));
      await tester.pumpAndSettle();

      // Send succeeds → code step → resend disabled during the initial window.
      await tester.enterText(find.byType(TextFormField), 'user@example.com');
      await tester.tap(find.byType(FilledButton));
      await tester.pump(const Duration(milliseconds: 100));

      final resendButton = find.byType(TextButton).first;
      expect(tester.widget<TextButton>(resendButton).onPressed, isNull);

      // The window elapses → resend re-enables.
      await tester.pump(const Duration(seconds: 61));
      expect(tester.widget<TextButton>(resendButton).onPressed, isNotNull);

      // Resend → the window must restart, disabling resend again so the next
      // request cannot fire straight into the server's rate limit.
      await tester.tap(resendButton);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.widget<TextButton>(resendButton).onPressed, isNull);

      // Drain the restarted ticker and the snackbar timer before teardown.
      await tester.pump(const Duration(seconds: 61));
    },
  );

  testWidgets(
    'submitting the code field empty or partial does not call the server',
    (tester) async {
      final repo = _CountingRepository();
      await tester.pumpWidget(_screen(repo));
      await tester.pumpAndSettle();

      // Advance to the code step.
      await tester.enterText(find.byType(TextFormField), 'user@example.com');
      await tester.tap(find.byType(FilledButton));
      await tester.pump(const Duration(milliseconds: 100));

      // Focus the empty code field and fire the keyboard "done" action — it
      // only closes the keyboard; verify must not be called.
      await tester.tap(find.byType(TextFormField));
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(repo.verifyCount, 0);

      // A partial (< 6 digit) code must not submit on "done" either.
      await tester.enterText(find.byType(TextFormField), '123');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(repo.verifyCount, 0);

      // Drain the resend display ticker before teardown.
      await tester.pump(const Duration(seconds: 61));
    },
  );
}
