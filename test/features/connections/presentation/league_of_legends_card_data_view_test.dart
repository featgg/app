import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/connections/presentation/league_of_legends_card_data_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('LeagueOfLegendsCardDataView', () {
    testWidgets(
      'renders rank, W/L, summoner level, challenges, and mastery rows',
      (tester) async {
        const data = LeagueOfLegendsCardData(
          rank: LolRank(
            tier: 'GOLD',
            division: 'II',
            lp: 85,
            wins: 120,
            losses: 94,
          ),
          topMastery: [
            LolMasteryEntry(championId: 157, level: 7, points: 850000),
            LolMasteryEntry(championId: 64, level: 6, points: 350000),
          ],
          challenges: LolChallenges(totalPoints: 45000, level: 'GOLD'),
          summoner: LolSummoner(level: 312, profileIconId: 4568),
        );

        await tester.pumpWidget(
          _wrap(const LeagueOfLegendsCardDataView(data: data)),
        );

        expect(find.byKey(const Key('lolRankLabel')), findsOneWidget);
        expect(find.byKey(const Key('lolLpLabel')), findsOneWidget);
        expect(find.byKey(const Key('lolWinsLabel')), findsOneWidget);
        expect(find.byKey(const Key('lolLossesLabel')), findsOneWidget);
        expect(find.byKey(const Key('lolSummonerLevelLabel')), findsOneWidget);
        expect(find.byKey(const Key('lolChallengesHeading')), findsOneWidget);
        expect(find.byKey(const Key('lolChallengeLevelLabel')), findsOneWidget);
        expect(find.byKey(const Key('lolTopMasteryHeading')), findsOneWidget);
        expect(find.byKey(const Key('lolMasteryEntry_0')), findsOneWidget);
        expect(find.byKey(const Key('lolMasteryEntry_1')), findsOneWidget);
        // Unranked label must not appear when ranked.
        expect(find.byKey(const Key('lolUnrankedLabel')), findsNothing);
      },
    );

    testWidgets('unranked renders the unranked label and omits rank rows', (
      tester,
    ) async {
      const data = LeagueOfLegendsCardData(topMastery: []);

      await tester.pumpWidget(
        _wrap(const LeagueOfLegendsCardDataView(data: data)),
      );

      expect(find.byKey(const Key('lolUnrankedLabel')), findsOneWidget);
      expect(find.byKey(const Key('lolRankLabel')), findsNothing);
      expect(find.byKey(const Key('lolLpLabel')), findsNothing);
      expect(find.byKey(const Key('lolWinsLabel')), findsNothing);
      expect(find.byKey(const Key('lolLossesLabel')), findsNothing);
      // Optional sections absent when data absent.
      expect(find.byKey(const Key('lolChallengesHeading')), findsNothing);
      expect(find.byKey(const Key('lolTopMasteryHeading')), findsNothing);
    });

    testWidgets('a named champion replaces the numeric id in the mastery row', (
      tester,
    ) async {
      const data = LeagueOfLegendsCardData(
        topMastery: [
          LolMasteryEntry(
            championId: 157,
            championName: 'Yasuo',
            level: 7,
            points: 850000,
          ),
        ],
      );

      await tester.pumpWidget(
        _wrap(const LeagueOfLegendsCardDataView(data: data)),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.text('Yasuo'), findsOneWidget);
      expect(find.text('${l10n.connectionsLolChampion} 157'), findsNothing);
    });

    testWidgets('an unnamed champion still renders the labelled numeric id', (
      tester,
    ) async {
      const data = LeagueOfLegendsCardData(
        topMastery: [
          LolMasteryEntry(championId: 157, level: 7, points: 850000),
        ],
      );

      await tester.pumpWidget(
        _wrap(const LeagueOfLegendsCardDataView(data: data)),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.text('${l10n.connectionsLolChampion} 157'), findsOneWidget);
    });
  });
}
