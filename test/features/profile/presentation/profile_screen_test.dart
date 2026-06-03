import 'dart:async';

import 'package:featgg/src/core/core.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/profile/domain/profile_domain.dart';
import 'package:featgg/src/features/profile/presentation/profile_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Fake repository whose outcome is injected per test.
final class _FakeRepository implements ProfileRepository {
  _FakeRepository({required this.result});

  final Future<Either<Failure, Profile>> Function() result;
  int calls = 0;

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() {
    calls++;
    return result();
  }
}

/// Holds the future open indefinitely so the loading state is observable.
final class _PendingRepository implements ProfileRepository {
  final _completer = Completer<Either<Failure, Profile>>();

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() => _completer.future;
}

const _profile = Profile(
  id: 'user-1',
  username: 'testuser',
  displayName: 'Test User',
  avatarUrl: null,
  bio: 'My bio',
  privacy: ProfilePrivacy.public,
);

const _privateProfile = Profile(
  id: 'user-2',
  username: 'private',
  displayName: 'Private User',
  avatarUrl: null,
  bio: null,
  privacy: ProfilePrivacy.private,
);

Widget _screen(ProfileRepository repo) {
  final container = ProviderContainer(
    // Disable Riverpod's automatic retry so error states are stable in tests
    // and pending timers do not leak past teardown.
    retry: (count, error) => null,
    overrides: [profileRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ProfileScreen(),
    ),
  );
}

void main() {
  test('Left does not auto-retry (provider\'s own policy)', () async {
    // Build a container with NO retry: argument so container.retry is null.
    // Only the provider's own origin.retry == _noRetry can suppress the retry.
    final repo = _FakeRepository(
      result: () async => left(const NetworkFailure()),
    );
    final container = ProviderContainer(
      overrides: [profileRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    // Read the provider (triggers the build, which throws on Left).
    container.read(profileProvider);

    // Settle all pending microtasks so the Future completes.
    await Future<void>.microtask(() {});
    await Future<void>.microtask(() {});

    // fetchMyProfile must have been called exactly once — no auto-retry.
    expect(repo.calls, equals(1));

    // The provider's AsyncValue must be an AsyncError.
    expect(container.read(profileProvider), isA<AsyncError<Profile>>());
  });

  testWidgets('shows a loading indicator while the read is in flight', (
    tester,
  ) async {
    // Hold the future open so the loading state is observable without a timer.
    final repo = _PendingRepository();

    await tester.pumpWidget(_screen(repo));
    await tester.pump(); // one frame — loading state

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders identity fields on data', (tester) async {
    final repo = _FakeRepository(result: () async => right(_profile));

    await tester.pumpWidget(_screen(repo));
    await tester.pumpAndSettle();

    // Display name, handle, and bio are present as text nodes. The handle
    // assertion matches the username data value only — the surrounding ARB
    // template (the '@' prefix) is localized copy and must not be reproduced
    // here, so a copy edit to it cannot break this test.
    expect(find.text(_profile.displayName), findsOneWidget);
    expect(find.textContaining(_profile.username), findsOneWidget);
    expect(find.text(_profile.bio!), findsOneWidget);

    // Avatar widget is present (icon placeholder when avatarUrl is null).
    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('renders the error view with Retry on Left', (tester) async {
    final repo = _FakeRepository(
      result: () async => left(const NetworkFailure()),
    );

    await tester.pumpWidget(_screen(repo));
    await tester.pumpAndSettle();

    // The Retry button is present via its key.
    expect(find.byKey(const Key('asyncRetryButton')), findsOneWidget);

    final callsBefore = repo.calls;
    await tester.tap(find.byKey(const Key('asyncRetryButton')));
    await tester.pumpAndSettle();

    // Tapping Retry re-invokes fetchMyProfile.
    expect(repo.calls, greaterThan(callsBefore));
  });

  testWidgets('private profile shows the private indicator', (tester) async {
    final repo = _FakeRepository(result: () async => right(_privateProfile));

    await tester.pumpWidget(_screen(repo));
    await tester.pumpAndSettle();

    // The private icon is keyed; the public icon must not be present.
    expect(find.byKey(const Key('privacyPrivateIcon')), findsOneWidget);
    expect(find.byKey(const Key('privacyPublicIcon')), findsNothing);
  });
}
