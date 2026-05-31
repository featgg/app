import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:featgg/src/core/l10n/l10n.dart';

void main() {
  group('AppLocalizations', () {
    test('supportedLocales contains en, es, and pt', () {
      final locales = AppLocalizations.supportedLocales;
      expect(
        locales.map((l) => l.languageCode),
        containsAll(['en', 'es', 'pt']),
      );
    });

    test('resolves pt locale and returns Portuguese copy', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
      expect(l10n.errorNetwork, 'Verifique sua conexão e tente novamente.');
    });

    test('resolves es locale and returns Spanish copy', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('es'));
      expect(l10n.errorNetwork, 'Revisá tu conexión e intentá de nuevo.');
    });
  });
}
