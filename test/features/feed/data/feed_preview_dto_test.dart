import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/feed/data/feed_preview_dto.dart';
import 'package:flutter_test/flutter_test.dart';

// Feed-preview row map matching the Steam example from feed.md.
const _steamPreview = <String, dynamic>{
  'schema_version': 1,
  'platform': 'steam',
  'title': 'TestUser',
  'subtitle': null,
  'icon_image': 'https://avatars.akamai.steamstatic.com/abcdef_medium.jpg',
  'hero_image': null,
  'profile_url': 'https://steamcommunity.com/id/test/',
  'stats': [
    {'key': 'hours_played', 'value': 1240, 'unit': 'hours'},
    {'key': 'games_owned', 'value': 312, 'unit': 'count'},
  ],
  'last_updated': '2026-06-03T12:00:00Z',
};

FeedRowDto _steamRow({String userId = 'user-1'}) => FeedRowDto(
  userId: userId,
  platformWire: 'steam',
  lastUpdatedAt: '2026-06-03T12:00:00Z',
  feedPreview: Map<String, dynamic>.from(_steamPreview),
);

void main() {
  group('feedItemFromRowOrNull — valid row', () {
    test('Steam example → FeedItem with envelope fields and data == null', () {
      final item = feedItemFromRowOrNull(_steamRow());

      expect(item, isNotNull);
      expect(item!.userId, 'user-1');
      expect(item.card.platform, Platform.steam);
      expect(item.card.title, 'TestUser');
      expect(item.card.subtitle, isNull);
      expect(
        item.card.iconImage,
        'https://avatars.akamai.steamstatic.com/abcdef_medium.jpg',
      );
      expect(item.card.heroImage, isNull);
      expect(item.card.profileUrl, 'https://steamcommunity.com/id/test/');
      expect(item.card.stats, hasLength(2));
      expect(item.card.stats.first.key, 'hours_played');
      expect(item.card.stats.first.value, 1240);
      expect(item.card.stats.first.unit, 'hours');
      expect(item.card.lastUpdated, DateTime.utc(2026, 6, 3, 12));
      // feed_preview carries no data block.
      expect(item.card.data, isNull);
    });

    test('schemaVersion is 1 → FeedItem returned', () {
      final item = feedItemFromRowOrNull(_steamRow());
      expect(item, isNotNull);
      expect(item!.card.schemaVersion, 1);
    });
  });

  group('feedItemFromRowOrNull — drop cases', () {
    test('unknown platform → null (row dropped)', () {
      final row = FeedRowDto(
        userId: 'user-1',
        platformWire: 'future_platform_x',
        lastUpdatedAt: '2026-06-03T12:00:00Z',
        feedPreview: Map<String, dynamic>.from(_steamPreview),
      );
      expect(feedItemFromRowOrNull(row), isNull);
    });

    test('non-v1 schema_version → null (row dropped)', () {
      final preview = Map<String, dynamic>.from(_steamPreview)
        ..['schema_version'] = 2;
      final row = FeedRowDto(
        userId: 'user-1',
        platformWire: 'steam',
        lastUpdatedAt: '2026-06-03T12:00:00Z',
        feedPreview: preview,
      );
      expect(feedItemFromRowOrNull(row), isNull);
    });

    test(
      'malformed envelope (missing required field) → null (row dropped)',
      () {
        // Remove the required 'title' field to force a parse failure.
        final badPreview = Map<String, dynamic>.from(_steamPreview)
          ..remove('title');
        final row = FeedRowDto(
          userId: 'user-1',
          platformWire: 'steam',
          lastUpdatedAt: '2026-06-03T12:00:00Z',
          feedPreview: badPreview,
        );
        expect(feedItemFromRowOrNull(row), isNull);
      },
    );

    test('empty feedPreview map → null (row dropped, not thrown)', () {
      final row = FeedRowDto(
        userId: 'user-1',
        platformWire: 'steam',
        lastUpdatedAt: '2026-06-03T12:00:00Z',
        feedPreview: const {},
      );
      expect(feedItemFromRowOrNull(row), isNull);
    });
  });

  group(
    'feedItemFromRowOrNull — all known platforms parse without throwing',
    () {
      for (final platformWire in [
        'steam',
        'league_of_legends',
        'wow_retail',
        'minecraft_hypixel',
        'chess',
        'retroachievements',
        'gw2',
      ]) {
        test('platform=$platformWire', () {
          final preview = Map<String, dynamic>.from(_steamPreview)
            ..['platform'] = platformWire;
          final row = FeedRowDto(
            userId: 'user-1',
            platformWire: platformWire,
            lastUpdatedAt: '2026-06-03T12:00:00Z',
            feedPreview: preview,
          );
          // Must not throw; result may be null (if the platform is unknown) but
          // here all are known so we expect a non-null FeedItem.
          expect(feedItemFromRowOrNull(row), isNotNull);
        });
      }
    },
  );

  group('FeedRowDto', () {
    test('fields are stored as-is', () {
      final row = _steamRow(userId: 'abc-123');
      expect(row.userId, 'abc-123');
      expect(row.platformWire, 'steam');
      expect(row.lastUpdatedAt, '2026-06-03T12:00:00Z');
      expect(row.feedPreview['schema_version'], 1);
    });
  });
}
