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

    test(
      'new connections keys exist and are non-empty in all locales',
      () async {
        final en = await AppLocalizations.delegate.load(const Locale('en'));
        final es = await AppLocalizations.delegate.load(const Locale('es'));
        final pt = await AppLocalizations.delegate.load(const Locale('pt'));

        for (final l10n in [en, es, pt]) {
          expect(l10n.errorAlreadyLinked, isNotEmpty);
          expect(l10n.errorSyncCooldown, isNotEmpty);
          expect(l10n.errorUpstream, isNotEmpty);
          expect(l10n.connectionsTitle, isNotEmpty);
          expect(l10n.connectionsEntry, isNotEmpty);
          expect(l10n.connectionsEmpty, isNotEmpty);
          expect(l10n.connectionsAddSteam, isNotEmpty);
          expect(l10n.connectionsSteamRemoteIdLabel, isNotEmpty);
          expect(l10n.connectionsSteamRemoteIdHint, isNotEmpty);
          expect(l10n.connectionsRemoteIdRequired, isNotEmpty);
          expect(l10n.connectionsLink, isNotEmpty);
          expect(l10n.connectionsLinked, isNotEmpty);
          expect(l10n.connectionsRefresh, isNotEmpty);
          expect(l10n.connectionsRefreshSkipped, isNotEmpty);
          expect(l10n.connectionsRefreshCooldown, isNotEmpty);
          expect(l10n.connectionsUnlink, isNotEmpty);
          expect(l10n.connectionsUnlinked, isNotEmpty);
          expect(l10n.connectionsStatusActive, isNotEmpty);
          expect(l10n.connectionsStatusError, isNotEmpty);
          expect(l10n.connectionsLastSyncNever, isNotEmpty);
          expect(l10n.connectionsCardProfileLink, isNotEmpty);
          expect(l10n.connectionsStatHoursPlayed, isNotEmpty);
          expect(l10n.connectionsStatGamesOwned, isNotEmpty);
          expect(l10n.connectionsLastSync('2026-06-05'), isNotEmpty);
          expect(l10n.connectionsLibraryShowcase, isNotEmpty);
          expect(l10n.connectionsRecentGames, isNotEmpty);
          expect(l10n.errorUpstreamNotFound, isNotEmpty);
          expect(l10n.errorUpstreamNotConnected, isNotEmpty);
          expect(l10n.errorUpstreamReconnect, isNotEmpty);
        }
      },
    );

    test('new connections keys differ across locales', () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      final es = await AppLocalizations.delegate.load(const Locale('es'));
      final pt = await AppLocalizations.delegate.load(const Locale('pt'));

      expect(es.connectionsTitle, isNot(en.connectionsTitle));
      expect(pt.connectionsTitle, isNot(en.connectionsTitle));
      expect(es.errorAlreadyLinked, isNot(en.errorAlreadyLinked));
      expect(pt.errorAlreadyLinked, isNot(en.errorAlreadyLinked));
      expect(es.errorUpstreamNotFound, isNot(en.errorUpstreamNotFound));
      expect(pt.errorUpstreamNotFound, isNot(en.errorUpstreamNotFound));
      expect(es.errorUpstreamReconnect, isNot(en.errorUpstreamReconnect));
      expect(pt.errorUpstreamReconnect, isNot(en.errorUpstreamReconnect));
    });
  });
}
