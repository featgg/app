import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:featgg/src/core/l10n/l10n.dart';

void main() {
  group('AppLocalizations', () {
    test('supportedLocales contains en, es, and pt', () {
      expect(
        AppLocalizations.supportedLocales.map((l) => l.languageCode),
        containsAll(['en', 'es', 'pt']),
      );
    });

    test(
      'each supported locale loads its own copy, not the template fallback',
      () async {
        final en = await AppLocalizations.delegate.load(const Locale('en'));
        final es = await AppLocalizations.delegate.load(const Locale('es'));
        final pt = await AppLocalizations.delegate.load(const Locale('pt'));

        // Every locale resolves to non-empty copy for a representative key...
        expect(en.errorNetwork, isNotEmpty);
        expect(es.errorNetwork, isNotEmpty);
        expect(pt.errorNetwork, isNotEmpty);

        // ...and to distinct copy per locale, proving the locale-specific ARB
        // loaded rather than falling back to the template. Asserts behavior, not
        // the literal translation (copy lives in the ARB files and is edited
        // freely).
        expect(es.errorNetwork, isNot(en.errorNetwork));
        expect(pt.errorNetwork, isNot(en.errorNetwork));
        expect(es.errorNetwork, isNot(pt.errorNetwork));
      },
    );
  });
}
