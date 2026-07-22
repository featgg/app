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

    test('new connections keys exist and are non-empty in all locales', () async {
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
        expect(l10n.connectionsConnectPlatform('Steam'), isNotEmpty);
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
        expect(l10n.connectionsStatNetworkLevel, isNotEmpty);
        expect(l10n.connectionsStatBedwarsWins, isNotEmpty);
        expect(l10n.connectionsStatBedwarsKills, isNotEmpty);
        expect(l10n.connectionsStatKarma, isNotEmpty);
        expect(l10n.connectionsStatAchievementPoints, isNotEmpty);
        expect(l10n.connectionsMinecraftRemoteIdLabel, isNotEmpty);
        expect(l10n.connectionsMinecraftRemoteIdHint, isNotEmpty);
        expect(l10n.connectionsMinecraftRemoteIdRequired, isNotEmpty);
        expect(l10n.connectionsMinecraftRank, isNotEmpty);
        expect(l10n.connectionsMinecraftLevel, isNotEmpty);
        expect(l10n.connectionsMinecraftKarma, isNotEmpty);
        expect(l10n.connectionsMinecraftGameStats, isNotEmpty);
        expect(l10n.connectionsMinecraftBedwars, isNotEmpty);
        expect(l10n.connectionsMinecraftSkywars, isNotEmpty);
        expect(l10n.connectionsMinecraftDuels, isNotEmpty);
        expect(l10n.connectionsMinecraftWins, isNotEmpty);
        expect(l10n.connectionsMinecraftKills, isNotEmpty);
        expect(l10n.connectionsMinecraftFinalKills, isNotEmpty);
        expect(l10n.connectionsMinecraftBedsBroken, isNotEmpty);
        expect(l10n.connectionsMinecraftStar, isNotEmpty);
        expect(l10n.connectionsStatTotalAchievementPoints, isNotEmpty);
        expect(l10n.connectionsStatRetroRank, isNotEmpty);
        expect(l10n.connectionsStatCompletionPct, isNotEmpty);
        expect(l10n.connectionsRetroAchievementsRemoteIdLabel, isNotEmpty);
        expect(l10n.connectionsRetroAchievementsRemoteIdHint, isNotEmpty);
        expect(l10n.connectionsRetroAchievementsRemoteIdRequired, isNotEmpty);
        expect(l10n.connectionsRetroAchievementsRank, isNotEmpty);
        expect(l10n.connectionsRetroAchievementsTotalPoints, isNotEmpty);
        expect(l10n.connectionsRetroAchievementsTruePoints, isNotEmpty);
        expect(l10n.connectionsRetroAchievementsSoftcorePoints, isNotEmpty);
        expect(l10n.connectionsRetroAchievementsMemberSince, isNotEmpty);
        expect(l10n.connectionsRetroAchievementsRecentGames, isNotEmpty);
        expect(l10n.errorUpstreamNotFound, isNotEmpty);
        expect(l10n.errorUpstreamNotConnected, isNotEmpty);
        expect(l10n.errorUpstreamReconnect, isNotEmpty);
        // LoL form keys
        expect(l10n.connectionsLolGameNameLabel, isNotEmpty);
        expect(l10n.connectionsLolGameNameHint, isNotEmpty);
        expect(l10n.connectionsLolGameNameRequired, isNotEmpty);
        expect(l10n.connectionsLolTagLineLabel, isNotEmpty);
        expect(l10n.connectionsLolTagLineHint, isNotEmpty);
        expect(l10n.connectionsLolTagLineRequired, isNotEmpty);
        expect(l10n.connectionsLolRegionLabel, isNotEmpty);
        expect(l10n.connectionsLolRegionHint, isNotEmpty);
        expect(l10n.connectionsLolRegionRequired, isNotEmpty);
        // LoL card display keys
        expect(l10n.connectionsLolRank, isNotEmpty);
        expect(l10n.connectionsLolUnranked, isNotEmpty);
        expect(l10n.connectionsLolLp, isNotEmpty);
        expect(l10n.connectionsLolWins, isNotEmpty);
        expect(l10n.connectionsLolLosses, isNotEmpty);
        expect(l10n.connectionsLolSummonerLevel, isNotEmpty);
        expect(l10n.connectionsLolChallenges, isNotEmpty);
        expect(l10n.connectionsLolChallengeLevel, isNotEmpty);
        expect(l10n.connectionsLolTopMastery, isNotEmpty);
        expect(l10n.connectionsLolMasteryLevel, isNotEmpty);
        expect(l10n.connectionsLolChampion, isNotEmpty);
        // LoL stat row keys
        expect(l10n.connectionsStatRankLp, isNotEmpty);
        expect(l10n.connectionsStatWinrate, isNotEmpty);
        expect(l10n.connectionsStatMasteryPoints, isNotEmpty);
        expect(l10n.connectionsStatChallengePoints, isNotEmpty);
        expect(l10n.connectionsStatSummonerLevel, isNotEmpty);
        // Countdown keys: ICU plural — both singular and plural resolve non-empty.
        expect(l10n.connectionsRefreshCooldownCountdown(1), isNotEmpty);
        expect(l10n.connectionsRefreshCooldownCountdown(10), isNotEmpty);
        expect(l10n.profileAvatarCooldownCountdown(1), isNotEmpty);
        expect(l10n.profileAvatarCooldownCountdown(10), isNotEmpty);
      }
    });

    test(
      'countdown ICU plural keys yield distinct =1 vs other forms in all locales',
      () async {
        final en = await AppLocalizations.delegate.load(const Locale('en'));
        final es = await AppLocalizations.delegate.load(const Locale('es'));
        final pt = await AppLocalizations.delegate.load(const Locale('pt'));

        for (final l10n in [en, es, pt]) {
          // =1 and other must produce structurally distinct strings (the =1 form
          // spells out "1 second" / "1 segundo" and the other form interpolates
          // the count). Asserts structural difference, not literal text.
          expect(
            l10n.connectionsRefreshCooldownCountdown(1),
            isNot(l10n.connectionsRefreshCooldownCountdown(10)),
          );
          expect(
            l10n.profileAvatarCooldownCountdown(1),
            isNot(l10n.profileAvatarCooldownCountdown(10)),
          );
        }
      },
    );

    test(
      'new account-section keys exist and are non-empty in all locales',
      () async {
        final en = await AppLocalizations.delegate.load(const Locale('en'));
        final es = await AppLocalizations.delegate.load(const Locale('es'));
        final pt = await AppLocalizations.delegate.load(const Locale('pt'));

        for (final l10n in [en, es, pt]) {
          expect(l10n.settingsAccountSection, isNotEmpty);
          expect(l10n.accountEmailLabel, isNotEmpty);
          expect(l10n.accountProviderLabel, isNotEmpty);
          expect(l10n.accountProviderEmail, isNotEmpty);
          expect(l10n.accountProviderGoogle, isNotEmpty);
          expect(l10n.accountProviderDiscord, isNotEmpty);
          expect(l10n.accountDeletionPendingTitle, isNotEmpty);
          expect(l10n.accountDeletionPendingBody, isNotEmpty);
          expect(l10n.accountCancelDeletionButton, isNotEmpty);
          expect(l10n.accountDeletionCancelled, isNotEmpty);
          // Countdown is an ICU plural — both =1 and other forms resolve, and
          // are structurally distinct (=1 spells out one day, other interpolates).
          expect(l10n.accountDeletionCountdown(1), isNotEmpty);
          expect(l10n.accountDeletionCountdown(10), isNotEmpty);
          expect(
            l10n.accountDeletionCountdown(1),
            isNot(l10n.accountDeletionCountdown(10)),
          );
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
      // Representative new Minecraft keys load per-locale copy rather than the
      // template fallback. Brand mode names (Bed Wars, SkyWars) are
      // intentionally identical across locales, so they are not asserted here.
      expect(
        es.connectionsMinecraftRemoteIdLabel,
        isNot(en.connectionsMinecraftRemoteIdLabel),
      );
      expect(
        pt.connectionsMinecraftRemoteIdLabel,
        isNot(en.connectionsMinecraftRemoteIdLabel),
      );
      expect(
        es.connectionsStatNetworkLevel,
        isNot(en.connectionsStatNetworkLevel),
      );
      expect(
        pt.connectionsStatNetworkLevel,
        isNot(en.connectionsStatNetworkLevel),
      );
      // Representative new RetroAchievements keys load per-locale copy. Brand
      // terms (RetroPoints, the RetroAchievements proper noun) are identical
      // across locales, so they are not asserted here.
      expect(
        es.connectionsRetroAchievementsRemoteIdLabel,
        isNot(en.connectionsRetroAchievementsRemoteIdLabel),
      );
      expect(
        pt.connectionsRetroAchievementsRemoteIdLabel,
        isNot(en.connectionsRetroAchievementsRemoteIdLabel),
      );
      expect(
        es.connectionsStatTotalAchievementPoints,
        isNot(en.connectionsStatTotalAchievementPoints),
      );
      expect(
        pt.connectionsStatTotalAchievementPoints,
        isNot(en.connectionsStatTotalAchievementPoints),
      );
      // Representative LoL keys load per-locale copy. Brand abbreviations
      // (e.g. "Tag Line") are identical across locales and are not asserted.
      // connectionsLolLp is "LP" in both en and es but "PdL" in pt — assert
      // only pt≠en to avoid a false-identical failure on the es pair.
      expect(
        es.connectionsLolGameNameLabel,
        isNot(en.connectionsLolGameNameLabel),
      );
      expect(
        pt.connectionsLolGameNameLabel,
        isNot(en.connectionsLolGameNameLabel),
      );
      expect(pt.connectionsLolLp, isNot(en.connectionsLolLp));
      expect(es.connectionsStatRankLp, isNot(en.connectionsStatRankLp));
      expect(pt.connectionsStatRankLp, isNot(en.connectionsStatRankLp));
      expect(es.connectionsStatWinrate, isNot(en.connectionsStatWinrate));
      expect(pt.connectionsStatWinrate, isNot(en.connectionsStatWinrate));
    });

    test('new Collection / Achievement Grid keys exist and are non-empty, and '
        'translate per locale', () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      final es = await AppLocalizations.delegate.load(const Locale('es'));
      final pt = await AppLocalizations.delegate.load(const Locale('pt'));

      for (final l10n in [en, es, pt]) {
        expect(l10n.personalizationCollectionTitle, isNotEmpty);
        expect(l10n.personalizationStatGames, isNotEmpty);
        expect(l10n.personalizationStatPerfect, isNotEmpty);
      }

      // Non-brand copy loads per-locale, not the template fallback.
      expect(
        es.personalizationCollectionTitle,
        isNot(en.personalizationCollectionTitle),
      );
      expect(
        pt.personalizationCollectionTitle,
        isNot(en.personalizationCollectionTitle),
      );
      expect(es.personalizationStatGames, isNot(en.personalizationStatGames));
      expect(pt.personalizationStatGames, isNot(en.personalizationStatGames));
      expect(
        es.personalizationStatPerfect,
        isNot(en.personalizationStatPerfect),
      );
      expect(
        pt.personalizationStatPerfect,
        isNot(en.personalizationStatPerfect),
      );
    });
  });
}
