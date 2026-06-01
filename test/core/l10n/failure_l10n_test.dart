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
  });
}
