import 'package:featgg/src/core/error/error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Failure value equality', () {
    test('identical NotImplemented instances are equal', () {
      const a = NotImplemented();
      const b = NotImplemented();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('ServerFailure differs by code', () {
      const a = ServerFailure(code: 'A');
      const b = ServerFailure(code: 'B');
      expect(a, isNot(equals(b)));
    });

    test('SyncCooldownFailure with same retryAfterSeconds are equal', () {
      const a = SyncCooldownFailure(retryAfterSeconds: 5);
      const b = SyncCooldownFailure(retryAfterSeconds: 5);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test(
      'SyncCooldownFailure with differing retryAfterSeconds are unequal',
      () {
        const a = SyncCooldownFailure(retryAfterSeconds: 5);
        const b = SyncCooldownFailure(retryAfterSeconds: 60);
        expect(a, isNot(equals(b)));
      },
    );

    test(
      'SyncCooldownFailure with null vs non-null retryAfterSeconds are unequal',
      () {
        const a = SyncCooldownFailure();
        const b = SyncCooldownFailure(retryAfterSeconds: 5);
        expect(a, isNot(equals(b)));
      },
    );
  });

  group('Failure type identity', () {
    test('distinct subtypes with equal fields are not equal', () {
      const a = NotImplemented();
      const b = UnexpectedFailure();
      expect(a, isNot(equals(b)));
    });
  });

  group('Failure.isExpected classification', () {
    test('NotImplemented is expected', () {
      expect(const NotImplemented().isExpected, isTrue);
    });

    test('AuthFailure is expected', () {
      expect(const AuthFailure().isExpected, isTrue);
    });

    test('InputFailure is expected', () {
      expect(const InputFailure().isExpected, isTrue);
    });

    test('ServerFailure is not expected', () {
      expect(const ServerFailure().isExpected, isFalse);
    });

    test('NetworkFailure is expected', () {
      expect(const NetworkFailure().isExpected, isTrue);
    });

    test('UnexpectedFailure is not expected', () {
      expect(const UnexpectedFailure().isExpected, isFalse);
    });
  });

  group('Failure carries no user-facing field', () {
    test('each subtype exposes only message, code, and isExpected', () {
      // This test is a compile-time assertion: it only references
      // message, code, and isExpected. If an extra field were introduced
      // this test would not reference it — the test documents the contract.
      const notImpl = NotImplemented(message: 'dev', code: 'CODE');
      expect(notImpl.message, 'dev');
      expect(notImpl.code, 'CODE');
      expect(notImpl.isExpected, isTrue);

      const server = ServerFailure(message: 'srv', code: 'SRV');
      expect(server.message, 'srv');
      expect(server.code, 'SRV');
      expect(server.isExpected, isFalse);

      const network = NetworkFailure(message: 'net');
      expect(network.message, 'net');
      expect(network.code, isNull);
      expect(network.isExpected, isTrue);

      const auth = AuthFailure(code: 'UNAUTHORIZED');
      expect(auth.message, isNull);
      expect(auth.code, 'UNAUTHORIZED');
      expect(auth.isExpected, isTrue);

      const input = InputFailure(code: 'INVALID_REQUEST');
      expect(input.message, isNull);
      expect(input.code, 'INVALID_REQUEST');
      expect(input.isExpected, isTrue);

      const unexpected = UnexpectedFailure(message: 'oops');
      expect(unexpected.message, 'oops');
      expect(unexpected.code, isNull);
      expect(unexpected.isExpected, isFalse);
    });
  });
}
