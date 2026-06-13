import 'dart:async';

import 'package:featgg/src/core/core.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/settings/domain/settings_domain.dart';
import 'package:featgg/src/features/settings/presentation/settings_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

final class _FakeRepo implements AccountDeletionRepository {
  _FakeRepo({
    Future<Either<Failure, Unit>> Function()? request,
    Either<Failure, DeletionSchedule> Function()? confirm,
  }) : _request = request ?? (() async => right(unit)),
       _confirm =
           confirm ??
           (() =>
               right(DeletionSchedule(scheduledAt: DateTime.utc(2026, 6, 18))));

  final Future<Either<Failure, Unit>> Function() _request;
  final Either<Failure, DeletionSchedule> Function() _confirm;
  int requestCalls = 0;

  @override
  Future<Either<Failure, Unit>> requestDeletion() {
    requestCalls++;
    return _request();
  }

  @override
  Future<Either<Failure, DeletionSchedule>> confirmDeletion(
    String code,
  ) async => _confirm();

  @override
  Future<Either<Failure, Unit>> cancelDeletion() async => right(unit);
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  AccountDeletionRepository repo,
) async {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [accountDeletionRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AccountDeletionScreen(),
      ),
    ),
  );
  return container;
}

void main() {
  testWidgets('idle renders the request button', (tester) async {
    await _pump(tester, _FakeRepo());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('deleteAccountRequestButton')), findsOneWidget);
  });

  testWidgets(
    'confirming the dialog requests a code and shows the code field',
    (tester) async {
      final repo = _FakeRepo();
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('deleteAccountRequestButton')));
      await tester.pumpAndSettle(); // dialog opens
      await tester.tap(
        find.byKey(const Key('deleteAccountConfirmDialogConfirm')),
      );
      await tester.pump(); // dialog pops, requestCode runs
      await tester.pump(); // state → awaiting

      expect(repo.requestCalls, 1);
      expect(find.byKey(const Key('deleteAccountCodeField')), findsOneWidget);

      await tester.pump(const Duration(seconds: 61)); // drain cooldown + ticker
    },
  );

  testWidgets('a request in flight shows a spinner', (tester) async {
    final completer = Completer<Either<Failure, Unit>>();
    final repo = _FakeRepo(request: () => completer.future);
    await _pump(tester, repo);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('deleteAccountRequestButton')));
    await tester.pumpAndSettle(); // dialog
    await tester.tap(
      find.byKey(const Key('deleteAccountConfirmDialogConfirm')),
    );
    await tester.pump(); // dialog pops, requestCode starts (submitting: true)
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(right(unit)); // finish so no future leaks
    await tester.pump();
    await tester.pump(const Duration(seconds: 61)); // drain
  });

  testWidgets('a wrong code shows the error affordance', (tester) async {
    final repo = _FakeRepo(confirm: () => left(const InputFailure()));
    final container = await _pump(tester, repo);
    await tester.pumpAndSettle();

    final notifier = container.read(accountDeletionControllerProvider.notifier);
    await notifier.requestCode(); // → awaiting (starts cooldown)
    await tester.pump();
    await notifier.confirmCode('000000'); // Left → stays awaiting with failure
    await tester.pump();

    expect(find.byKey(const Key('deleteAccountCodeError')), findsOneWidget);

    await tester.pump(const Duration(seconds: 61)); // drain
  });

  testWidgets('the scheduled state shows the scheduled-date surface', (
    tester,
  ) async {
    final repo = _FakeRepo();
    final container = await _pump(tester, repo);
    await tester.pumpAndSettle();

    final notifier = container.read(accountDeletionControllerProvider.notifier);
    await notifier.requestCode(); // → awaiting (starts cooldown)
    await tester.pump();
    await notifier.confirmCode('123456'); // → scheduled
    await tester.pump();

    expect(
      find.byKey(const Key('deleteAccountScheduledTitle')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('deleteAccountScheduledBody')), findsOneWidget);

    await tester.pump(const Duration(seconds: 61)); // drain the cooldown timer
  });

  testWidgets('resend is gated during the cooldown — a tap starts no second '
      'request — and re-enables after the window', (tester) async {
    final repo = _FakeRepo();
    final container = await _pump(tester, repo);
    await tester.pumpAndSettle();

    await container
        .read(accountDeletionControllerProvider.notifier)
        .requestCode();
    await tester.pump();
    await tester.pump();
    expect(repo.requestCalls, 1);

    final resend = find.byKey(const Key('deleteAccountResendButton'));
    // Disabled during the cooldown; a tap is a no-op (the debounce gate).
    expect(tester.widget<TextButton>(resend).onPressed, isNull);
    await tester.tap(resend, warnIfMissed: false);
    await tester.pump();
    expect(repo.requestCalls, 1);

    // Re-enables once the cooldown window elapses.
    await tester.pump(const Duration(seconds: 61));
    expect(tester.widget<TextButton>(resend).onPressed, isNotNull);
  });

  testWidgets('the scheduled state offers cancel, and cancelling shows the '
      'cancelled state', (tester) async {
    final repo = _FakeRepo();
    final container = await _pump(tester, repo);
    await tester.pumpAndSettle();

    final notifier = container.read(accountDeletionControllerProvider.notifier);
    await notifier.requestCode();
    await tester.pump();
    await notifier.confirmCode('123456');
    await tester.pump();

    // The scheduled step provides the cancel affordance the copy promises.
    final cancel = find.byKey(const Key('deleteAccountCancelButton'));
    expect(cancel, findsOneWidget);

    await tester.tap(cancel);
    await tester.pump(); // cancelDeletion runs
    await tester.pump(); // → cancelled step

    expect(
      find.byKey(const Key('deleteAccountCancelledTitle')),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 61)); // drain the cooldown timer
  });
}
