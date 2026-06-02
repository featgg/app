import 'package:featgg/main.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/auth/domain/auth_domain.dart';
import 'package:featgg/src/features/home/presentation/home_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Signed-in repository so the session-gated redirect resolves to the home
/// route; the redirect itself is exercised in router_redirect_test.dart.
final class _SignedInAuthRepository implements AuthRepository {
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
  Future<Either<Failure, Unit>> signOut() async => right(unit);
}

Widget _signedInApp() {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(_SignedInAuthRepository()),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(container: container, child: const App());
}

void main() {
  group('router', () {
    testWidgets('resolves the root route to the home screen when signed in', (
      tester,
    ) async {
      await tester.pumpWidget(_signedInApp());
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('App applies AppTheme via MaterialApp.router', (tester) async {
      await tester.pumpWidget(_signedInApp());
      await tester.pumpAndSettle();
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.theme?.useMaterial3, isTrue);
    });
  });
}
