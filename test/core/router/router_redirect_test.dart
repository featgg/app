import 'dart:async';

import 'package:featgg/main.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/router/router.dart';
import 'package:featgg/src/features/auth/domain/auth_domain.dart';
import 'package:featgg/src/features/auth/presentation/auth_presentation.dart';
import 'package:featgg/src/features/home/presentation/home_presentation.dart';
import 'package:featgg/src/features/profile/domain/profile_domain.dart';
import 'package:featgg/src/features/profile/presentation/profile_presentation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

final class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._initial, [this._stream = const Stream.empty()]);

  final AuthStatus _initial;
  final Stream<AuthStatus> _stream;

  @override
  AuthStatus currentStatus() => _initial;

  @override
  Stream<AuthStatus> statusChanges() => _stream;

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

  @override
  Future<Either<Failure, Unit>> signOut() async => right(unit);
}

/// Profile repository whose future never completes, keeping ProfileScreen in
/// a stable loading state — navigation tests do not need real profile data.
final class _PendingProfileRepository implements ProfileRepository {
  final _completer = Completer<Either<Failure, Profile>>();

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() => _completer.future;

  @override
  Future<Either<Failure, Profile>> updateMyProfile(ProfileEdit edit) =>
      _completer.future;
}

Widget _app(AuthRepository repo) {
  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(container: container, child: const App());
}

Widget _signedInAppWithProfile() {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        _FakeAuthRepository(AuthStatus.signedIn),
      ),
      profileRepositoryProvider.overrideWithValue(_PendingProfileRepository()),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(container: container, child: const App());
}

void main() {
  group('router redirect', () {
    testWidgets('signed-out lands on the sign-in screen', (tester) async {
      await tester.pumpWidget(_app(_FakeAuthRepository(AuthStatus.signedOut)));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);
    });

    testWidgets('signed-in lands on the home screen', (tester) async {
      await tester.pumpWidget(_app(_FakeAuthRepository(AuthStatus.signedIn)));
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(SignInScreen), findsNothing);
    });

    testWidgets('a sign-out emission redirects home to the sign-in screen', (
      tester,
    ) async {
      final controller = StreamController<AuthStatus>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        _app(_FakeAuthRepository(AuthStatus.signedIn, controller.stream)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);

      controller.add(AuthStatus.signedOut);
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);
    });

    testWidgets(
      'the router is built once — a same-state status change does not recreate it',
      (tester) async {
        final controller = StreamController<AuthStatus>();
        addTearDown(controller.close);
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              _FakeAuthRepository(AuthStatus.signedIn, controller.stream),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(container: container, child: const App()),
        );
        await tester.pumpAndSettle();
        final firstRouter = container.read(routerProvider);

        // A status change that does NOT flip signed-in/out (e.g. the ~hourly
        // token refresh re-emits signedIn) must not rebuild the provider or
        // recreate the router, so the nav stack is preserved.
        controller.add(AuthStatus.signedIn);
        await tester.pumpAndSettle();

        expect(identical(container.read(routerProvider), firstRouter), isTrue);
        expect(find.byType(HomePage), findsOneWidget);
      },
    );

    testWidgets('/profile/edit without a Profile extra redirects to /profile', (
      tester,
    ) async {
      await tester.pumpWidget(_signedInAppWithProfile());
      await tester.pumpAndSettle();

      // Navigate to /profile/edit with no extra — the route-level redirect
      // must send to /profile instead of crashing on the missing Profile.
      final context = tester.element(find.byType(HomePage));
      GoRouter.of(context).go('/profile/edit');
      // The redirect lands on /profile, which stays in a perpetual loading
      // state here (the pending repo never completes), so pump frames rather
      // than settling the spinner, which would never settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.byType(ProfileEditScreen), findsNothing);
    });
  });
}
