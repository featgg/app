import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/l10n.dart';

void main() {
  group('FailureL10n.localizedMessage', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('NetworkFailure maps to errorNetwork', () {
      expect(const NetworkFailure().localizedMessage(l10n), l10n.errorNetwork);
    });

    test('ServerFailure maps to errorServer', () {
      expect(const ServerFailure().localizedMessage(l10n), l10n.errorServer);
    });

    test('AuthFailure maps to errorAuth', () {
      expect(const AuthFailure().localizedMessage(l10n), l10n.errorAuth);
    });

    test('InputFailure maps to errorInput', () {
      expect(const InputFailure().localizedMessage(l10n), l10n.errorInput);
    });

    test('NotImplemented maps to errorNotImplemented', () {
      expect(
        const NotImplemented().localizedMessage(l10n),
        l10n.errorNotImplemented,
      );
    });

    test('UnexpectedFailure maps to errorUnexpected', () {
      expect(
        const UnexpectedFailure().localizedMessage(l10n),
        l10n.errorUnexpected,
      );
    });

    test('AuthRateLimitFailure maps to errorAuthRateLimited', () {
      expect(
        const AuthRateLimitFailure().localizedMessage(l10n),
        l10n.errorAuthRateLimited,
      );
    });

    test('ModerationRejectedFailure maps to errorAvatarRejected', () {
      expect(
        const ModerationRejectedFailure().localizedMessage(l10n),
        l10n.errorAvatarRejected,
      );
    });

    test('ModerationUnavailableFailure maps to errorAvatarUnavailable', () {
      expect(
        const ModerationUnavailableFailure().localizedMessage(l10n),
        l10n.errorAvatarUnavailable,
      );
    });

    test('RateLimitFailure maps to errorAvatarRateLimited', () {
      expect(
        const RateLimitFailure().localizedMessage(l10n),
        l10n.errorAvatarRateLimited,
      );
    });

    test('MediaProcessingFailure maps to errorAvatarProcessing', () {
      expect(
        const MediaProcessingFailure().localizedMessage(l10n),
        l10n.errorAvatarProcessing,
      );
    });

    test('AlreadyLinkedFailure maps to errorAlreadyLinked', () {
      expect(
        const AlreadyLinkedFailure().localizedMessage(l10n),
        l10n.errorAlreadyLinked,
      );
    });

    test('SyncCooldownFailure maps to errorSyncCooldown', () {
      expect(
        const SyncCooldownFailure().localizedMessage(l10n),
        l10n.errorSyncCooldown,
      );
    });

    test('UpstreamFailure (no code) maps to errorUpstream', () {
      expect(
        const UpstreamFailure().localizedMessage(l10n),
        l10n.errorUpstream,
      );
    });

    test(
      'UpstreamFailure UPSTREAM_NOT_FOUND maps to errorUpstreamNotFound',
      () {
        expect(
          const UpstreamFailure(
            code: 'UPSTREAM_NOT_FOUND',
          ).localizedMessage(l10n),
          l10n.errorUpstreamNotFound,
        );
      },
    );

    test(
      'UpstreamFailure LINKED_ACCOUNT_NOT_FOUND maps to errorUpstreamNotConnected',
      () {
        expect(
          const UpstreamFailure(
            code: 'LINKED_ACCOUNT_NOT_FOUND',
          ).localizedMessage(l10n),
          l10n.errorUpstreamNotConnected,
        );
      },
    );

    test(
      'UpstreamFailure MISSING_STORED_CREDENTIAL maps to errorUpstreamReconnect',
      () {
        expect(
          const UpstreamFailure(
            code: 'MISSING_STORED_CREDENTIAL',
          ).localizedMessage(l10n),
          l10n.errorUpstreamReconnect,
        );
      },
    );

    test(
      'UpstreamFailure INVALID_STORED_ROUTING maps to errorUpstreamReconnect',
      () {
        expect(
          const UpstreamFailure(
            code: 'INVALID_STORED_ROUTING',
          ).localizedMessage(l10n),
          l10n.errorUpstreamReconnect,
        );
      },
    );

    test(
      'input-correction, reconnect, and transient buckets produce distinct messages',
      () {
        final notFound = const UpstreamFailure(
          code: 'UPSTREAM_NOT_FOUND',
        ).localizedMessage(l10n);
        final notConnected = const UpstreamFailure(
          code: 'LINKED_ACCOUNT_NOT_FOUND',
        ).localizedMessage(l10n);
        final reconnect = const UpstreamFailure(
          code: 'MISSING_STORED_CREDENTIAL',
        ).localizedMessage(l10n);
        final transient = const UpstreamFailure().localizedMessage(l10n);

        expect(notFound, isNot(notConnected));
        expect(notFound, isNot(reconnect));
        expect(notFound, isNot(transient));
        expect(notConnected, isNot(reconnect));
        expect(notConnected, isNot(transient));
        expect(reconnect, isNot(transient));
      },
    );
  });
}
