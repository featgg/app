import 'package:featgg/main.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/theme/theme.dart';
import 'package:featgg/src/features/auth/domain/auth_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Signed-out auth so App's cold-start refresh hook short-circuits. App reads
/// authRepositoryProvider on the first frame, so pumping App now requires it.
final class _SignedOutAuthRepository implements AuthRepository {
  @override
  AuthStatus currentStatus() => AuthStatus.signedOut;

  @override
  AccountIdentity? currentIdentity() => null;

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

  @override
  Future<Either<Failure, Unit>> signOut() async => right(unit);
}

void main() {
  group('App', () {
    testWidgets('applies the token-derived theme', (tester) async {
      // Pump App directly inside ProviderScope. bootstrap() is intentionally
      // not called — it would throw because no --dart-define-from-file is
      // present in the test environment. authRepositoryProvider is overridden
      // because App's cold-start hook reads it on the first frame.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              _SignedOutAuthRepository(),
            ),
          ],
          child: const App(),
        ),
      );

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));

      expect(materialApp.theme, isNotNull);
      expect(materialApp.theme!.useMaterial3, isTrue);

      final expectedPrimary = ColorScheme.fromSeed(
        seedColor: AppColorTokens.seed,
      ).primary;
      expect(materialApp.theme!.colorScheme.primary, equals(expectedPrimary));
    });
  });
}
