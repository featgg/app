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
    await tester.pumpAndSettle();

    // Code step: enter the code and tap Verify (rate-limited).
    await tester.enterText(find.byType(TextFormField), '123456');
    final verifyButton = find.byType(FilledButton);
    expect(tester.widget<FilledButton>(verifyButton).onPressed, isNotNull);

    await tester.tap(verifyButton);
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(verifyButton).onPressed, isNull);

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
        await tester.pumpAndSettle();

        // Advanced to the code step; the in-flight spinner is gone.
        expect(find.byType(CircularProgressIndicator), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
