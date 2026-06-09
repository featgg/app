import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/feed/domain/feed_page.dart';
import 'package:featgg/src/features/feed/presentation/feed_item_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';

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

FeedItem _item({
  String userId = 'user-1',
  String title = 'TestUser',
  String? subtitle,
  String? iconImage,
  String? heroImage,
  Platform platform = Platform.steam,
  List<CardStat> stats = const [],
}) => FeedItem(
  userId: userId,
  card: GameCard(
    schemaVersion: 1,
    platform: platform,
    title: title,
    subtitle: subtitle,
    iconImage: iconImage,
    heroImage: heroImage,
    profileUrl: null,
    stats: stats,
    lastUpdated: DateTime.utc(2026, 6, 3),
    data: null,
  ),
);

void main() {
  group('FeedItemCard', () {
    testWidgets(
      'renders title with null iconImage and heroImage (no-image-first)',
      (tester) async {
        final item = _item(iconImage: null, heroImage: null);
        await tester.pumpWidget(_wrap(FeedItemCard(item: item)));
        await tester.pump();

        // Title is rendered.
        expect(find.byKey(const Key('feedCardTitle')), findsOneWidget);
        expect(find.text('TestUser'), findsOneWidget);

        // When iconImage is null, the placeholder is shown (not a network image).
        expect(
          find.byKey(const Key('feedCardIconPlaceholder')),
          findsOneWidget,
        );
        // No CachedNetworkImage for the icon.
        expect(find.byKey(const Key('feedCardIconImage')), findsNothing);
      },
    );

    testWidgets('renders subtitle when non-null', (tester) async {
      final item = _item(subtitle: 'na1');
      await tester.pumpWidget(_wrap(FeedItemCard(item: item)));
      await tester.pump();

      expect(find.byKey(const Key('feedCardSubtitle')), findsOneWidget);
      expect(find.text('na1'), findsOneWidget);
    });

    testWidgets('no subtitle widget when subtitle is null', (tester) async {
      final item = _item(subtitle: null);
      await tester.pumpWidget(_wrap(FeedItemCard(item: item)));
      await tester.pump();

      expect(find.byKey(const Key('feedCardSubtitle')), findsNothing);
    });

    testWidgets('renders up to 2 stat chips by key', (tester) async {
      final item = _item(
        stats: const [
          CardStat(key: 'hours_played', value: 1240, unit: 'hours'),
          CardStat(key: 'games_owned', value: 312, unit: 'count'),
        ],
      );
      await tester.pumpWidget(_wrap(FeedItemCard(item: item)));
      await tester.pump();

      expect(find.byKey(const Key('stat_hours_played')), findsOneWidget);
      expect(find.byKey(const Key('stat_games_owned')), findsOneWidget);
      expect(find.byKey(const Key('feedCardStats')), findsOneWidget);
    });

    testWidgets('renders at most 2 stat chips even with more stats', (
      tester,
    ) async {
      final item = _item(
        stats: const [
          CardStat(key: 'hours_played', value: 100, unit: 'hours'),
          CardStat(key: 'games_owned', value: 50, unit: 'count'),
          CardStat(key: 'rating', value: 1200),
        ],
      );
      await tester.pumpWidget(_wrap(FeedItemCard(item: item)));
      await tester.pump();

      // Only the first two chips are rendered.
      expect(find.byKey(const Key('stat_hours_played')), findsOneWidget);
      expect(find.byKey(const Key('stat_games_owned')), findsOneWidget);
      expect(find.byKey(const Key('stat_rating')), findsNothing);
    });

    testWidgets('no stats section when stats list is empty', (tester) async {
      final item = _item(stats: const []);
      await tester.pumpWidget(_wrap(FeedItemCard(item: item)));
      await tester.pump();

      expect(find.byKey(const Key('feedCardStats')), findsNothing);
    });

    testWidgets('per-platform accent chip is present', (tester) async {
      final item = _item(platform: Platform.chess);
      await tester.pumpWidget(_wrap(FeedItemCard(item: item)));
      await tester.pump();

      expect(find.byKey(const Key('feedCardPlatform_chess')), findsOneWidget);
    });

    testWidgets('card key includes userId', (tester) async {
      final item = _item(userId: 'abc-123');
      await tester.pumpWidget(_wrap(FeedItemCard(item: item)));
      await tester.pump();

      expect(find.byKey(const Key('feedCard_abc-123')), findsOneWidget);
    });
  });
}
