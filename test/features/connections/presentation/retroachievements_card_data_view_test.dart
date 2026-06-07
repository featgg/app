import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/connections/presentation/retroachievements_card_data_view.dart';
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
  home: Scaffold(body: child),
);

void main() {
  group('RetroAchievementsCardDataView', () {
    testWidgets('renders profile rows, member-since, motto, and recent games', (
      tester,
    ) async {
      // iconUrl is null so the box-art falls back to the placeholder — keeps the
      // widget test off the network.
      final data = RetroAchievementsCardData(
        profile: RetroAchievementsProfile(
          totalPoints: 48320,
          truePoints: 112500,
          softcorePoints: 320,
          rank: 1204,
          memberSince: DateTime.utc(2019, 3, 15),
          motto: 'Achievement hunter',
        ),
        recentGames: const [
          RetroAchievementsRecentGame(
            title: 'Sonic the Hedgehog',
            console: 'Mega Drive',
            achieved: 18,
            total: 22,
            completionPct: 81.8,
          ),
        ],
      );

      await tester.pumpWidget(_wrap(RetroAchievementsCardDataView(data: data)));

      expect(
        find.byKey(const Key('retroachievementsRankLabel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('retroachievementsTotalPointsLabel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('retroachievementsTruePointsLabel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('retroachievementsSoftcorePointsLabel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('retroachievementsMemberSinceLabel')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('retroachievementsMotto')), findsOneWidget);
      expect(
        find.byKey(const Key('retroachievementsRecentGames')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('retroachievementsRecentGame_0')),
        findsOneWidget,
      );
    });

    testWidgets('omits member-since, motto, and recent games when absent', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const RetroAchievementsCardDataView(
            data: RetroAchievementsCardData(
              profile: RetroAchievementsProfile(
                totalPoints: 1,
                truePoints: 2,
                softcorePoints: 0,
                rank: 5,
              ),
              recentGames: [],
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('retroachievementsRankLabel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('retroachievementsMemberSinceLabel')),
        findsNothing,
      );
      expect(find.byKey(const Key('retroachievementsMotto')), findsNothing);
      expect(
        find.byKey(const Key('retroachievementsRecentGames')),
        findsNothing,
      );
    });
  });
}
