import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/connections/presentation/wow_retail_card_data_view.dart';
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

const _profile = WowProfile(
  race: 'Orc',
  faction: 'HORDE',
  className: 'Shaman',
  spec: 'Enhancement',
  level: 70,
  ilvlAvg: 492,
  ilvlEquipped: 489,
);

final _run = WowMythicRun(
  keystoneLevel: 20,
  dungeonName: 'Dawn of the Infinite',
  completedTimestamp: DateTime.fromMillisecondsSinceEpoch(
    1717200000000,
    isUtc: true,
  ),
  durationMs: 1920000,
  isCompletedWithinTime: true,
  rating: 245.5,
);

final _achievement = WowRecentAchievement(
  id: 12345,
  name: 'Keystone Master',
  completedAt: DateTime.utc(2026, 5, 1),
);

final _freshData = WowRetailCardData(
  profile: _profile,
  mythicPlus: const WowMythicPlus(rating: 2450.5, bestRuns: []),
  recentAchievements: [_achievement],
  attribution: 'Data provided by Blizzard',
);

void main() {
  group('WowRetailCardDataView', () {
    testWidgets('renders profile, M+, and attribution for fresh data', (
      tester,
    ) async {
      final freshData = WowRetailCardData(
        profile: _profile,
        mythicPlus: WowMythicPlus(rating: 2450.5, bestRuns: [_run]),
        recentAchievements: [_achievement],
        attribution: 'Data provided by Blizzard',
      );
      final recentLastUpdated = DateTime.now().subtract(
        const Duration(days: 1),
      );

      await tester.pumpWidget(
        _wrap(
          WowRetailCardDataView(
            data: freshData,
            lastUpdated: recentLastUpdated,
          ),
        ),
      );

      expect(find.byKey(const Key('wowItemLevelLabel')), findsOneWidget);
      expect(find.byKey(const Key('wowClassLabel')), findsOneWidget);
      expect(find.byKey(const Key('wowSpecLabel')), findsOneWidget);
      expect(find.byKey(const Key('wowFactionLabel')), findsOneWidget);
      expect(find.byKey(const Key('wowLevelLabel')), findsOneWidget);
      expect(find.byKey(const Key('wowBestRun_0')), findsOneWidget);
      expect(find.byKey(const Key('wowAttribution')), findsOneWidget);
      expect(
        find.byKey(const Key('wowRecentAchievementsHeading')),
        findsOneWidget,
      );
      // Stale state must not appear for fresh data.
      expect(find.byKey(const Key('wowStaleState')), findsNothing);
    });

    testWidgets('absent M+ omits the M+ section', (tester) async {
      const noMpData = WowRetailCardData(
        profile: _profile,
        recentAchievements: [],
        attribution: 'Data provided by Blizzard',
      );
      final recentLastUpdated = DateTime.now().subtract(
        const Duration(days: 1),
      );

      await tester.pumpWidget(
        _wrap(
          WowRetailCardDataView(data: noMpData, lastUpdated: recentLastUpdated),
        ),
      );

      expect(find.byKey(const Key('wowItemLevelLabel')), findsOneWidget);
      expect(find.byKey(const Key('wowMythicRatingHeading')), findsNothing);
      expect(find.byKey(const Key('wowBestRunsHeading')), findsNothing);
      expect(find.byKey(const Key('wowBestRun_0')), findsNothing);
      expect(find.byKey(const Key('wowAttribution')), findsOneWidget);
      expect(find.byKey(const Key('wowStaleState')), findsNothing);
    });

    testWidgets(
      'present M+ block with no rating and no runs omits the section',
      (tester) async {
        const emptyMpData = WowRetailCardData(
          profile: _profile,
          mythicPlus: WowMythicPlus(rating: null, bestRuns: []),
          recentAchievements: [],
          attribution: 'Data provided by Blizzard',
        );
        final recentLastUpdated = DateTime.now().subtract(
          const Duration(days: 1),
        );

        await tester.pumpWidget(
          _wrap(
            WowRetailCardDataView(
              data: emptyMpData,
              lastUpdated: recentLastUpdated,
            ),
          ),
        );

        expect(find.byKey(const Key('wowItemLevelLabel')), findsOneWidget);
        expect(find.byKey(const Key('wowMythicRatingHeading')), findsNothing);
        expect(find.byKey(const Key('wowBestRunsHeading')), findsNothing);
        expect(find.byKey(const Key('wowAttribution')), findsOneWidget);
      },
    );

    testWidgets('data older than 30 days shows the stale state', (
      tester,
    ) async {
      final staleLastUpdated = DateTime.now().subtract(
        const Duration(days: 40),
      );

      await tester.pumpWidget(
        _wrap(
          WowRetailCardDataView(
            data: _freshData,
            lastUpdated: staleLastUpdated,
          ),
        ),
      );

      expect(find.byKey(const Key('wowStaleState')), findsOneWidget);
      // Data rows must not appear in the stale state.
      expect(find.byKey(const Key('wowItemLevelLabel')), findsNothing);
      expect(find.byKey(const Key('wowClassLabel')), findsNothing);
      // Attribution still shows in the stale state.
      expect(find.byKey(const Key('wowAttribution')), findsOneWidget);
    });

    testWidgets('recent data does not show the stale state', (tester) async {
      final recentLastUpdated = DateTime.now().subtract(
        const Duration(days: 1),
      );

      await tester.pumpWidget(
        _wrap(
          WowRetailCardDataView(
            data: _freshData,
            lastUpdated: recentLastUpdated,
          ),
        ),
      );

      expect(find.byKey(const Key('wowStaleState')), findsNothing);
      expect(find.byKey(const Key('wowItemLevelLabel')), findsOneWidget);
    });
  });
}
