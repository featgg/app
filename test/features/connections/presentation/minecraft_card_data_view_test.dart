import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/connections/presentation/minecraft_card_data_view.dart';
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
  group('MinecraftCardDataView', () {
    testWidgets('renders rank, level, karma and every present mode block', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const MinecraftCardDataView(
            data: MinecraftCardData(
              rank: 'MVP_PLUS',
              rankRaw: 'MVP+',
              level: 142,
              karma: 8750400,
              bedwars: MinecraftBedwarsStats(
                wins: 2340,
                kills: 18200,
                finalKills: 9100,
                bedsBroken: 4750,
                star: 142,
              ),
              skywars: MinecraftModeStats(wins: 840, kills: 5200),
              duels: MinecraftModeStats(wins: 410, kills: 2200),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('minecraftRankLabel')), findsOneWidget);
      expect(find.byKey(const Key('minecraftLevelLabel')), findsOneWidget);
      expect(find.byKey(const Key('minecraftKarmaLabel')), findsOneWidget);
      expect(find.byKey(const Key('minecraftGameStats')), findsOneWidget);
      expect(find.byKey(const Key('minecraftBedwars')), findsOneWidget);
      expect(find.byKey(const Key('minecraftSkywars')), findsOneWidget);
      expect(find.byKey(const Key('minecraftDuels')), findsOneWidget);
    });

    testWidgets(
      'omits the game-stats section when no mode blocks are present',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const MinecraftCardDataView(
              data: MinecraftCardData(rank: 'DEFAULT', level: 1, karma: 0),
            ),
          ),
        );

        expect(find.byKey(const Key('minecraftRankLabel')), findsOneWidget);
        expect(find.byKey(const Key('minecraftGameStats')), findsNothing);
        expect(find.byKey(const Key('minecraftBedwars')), findsNothing);
      },
    );

    testWidgets('falls back to the raw rank for an undocumented token', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const MinecraftCardDataView(
            data: MinecraftCardData(
              rank: 'SOME_FUTURE_RANK',
              rankRaw: 'Future',
              level: 1,
              karma: 0,
            ),
          ),
        ),
      );

      // The view renders the backend-supplied raw token (not localized copy)
      // when the rank is not one of the documented values — proving the
      // safe-fallback path structurally.
      expect(
        find.descendant(
          of: find.byKey(const Key('minecraftRankLabel')),
          matching: find.text('Future'),
        ),
        findsOneWidget,
      );
    });
  });
}
