import 'package:featgg/src/features/connections/data/game_card_dto.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:flutter_test/flutter_test.dart';

/// The full Steam widget_data example from feed.md.
const _steamWidgetData = {
  'schema_version': 1,
  'platform': 'steam',
  'title': 'TestUser',
  'subtitle': null,
  'icon_image': 'https://avatars.akamai.steamstatic.com/hash_full.jpg',
  'hero_image':
      'https://shared.akamai.steamstatic.com/steam/apps/730/library_600x900.jpg',
  'profile_url': 'https://steamcommunity.com/id/test/',
  'stats': [
    {'key': 'hours_played', 'value': 1240, 'unit': 'hours'},
    {'key': 'games_owned', 'value': 312, 'unit': 'count'},
  ],
  'last_updated': '2026-06-03T12:00:00Z',
  'data': {
    'library_showcase': [
      {
        'app_id': 730,
        'title': 'CS2',
        'hours': 540,
        'icon_image':
            'https://shared.akamai.steamstatic.com/steam/apps/730/capsule_184x69.jpg',
        'hero_image':
            'https://shared.akamai.steamstatic.com/steam/apps/730/library_600x900.jpg',
      },
    ],
    'recent_games': [
      {'app_id': 730, 'title': 'CS2', 'hours_2weeks': 12},
    ],
  },
};

void main() {
  group('gameCardFromDto — Steam widget_data example', () {
    late GameCard card;

    setUp(() {
      card = gameCardFromDto(
        GameCardDto.fromJson(Map<String, dynamic>.from(_steamWidgetData)),
      );
    });

    test('parses envelope fields', () {
      expect(card.schemaVersion, 1);
      expect(card.platform, Platform.steam);
      expect(card.title, 'TestUser');
      expect(card.subtitle, isNull);
      expect(card.iconImage, contains('hash_full'));
      expect(card.heroImage, contains('library_600x900'));
      expect(card.profileUrl, 'https://steamcommunity.com/id/test/');
      expect(card.lastUpdated, DateTime.parse('2026-06-03T12:00:00Z'));
    });

    test('parses stats array', () {
      expect(card.stats, hasLength(2));
      expect(card.stats[0].key, 'hours_played');
      expect(card.stats[0].value, 1240);
      expect(card.stats[0].unit, 'hours');
      expect(card.stats[1].key, 'games_owned');
      expect(card.stats[1].value, 312);
    });

    test('parses SteamCardData from data block', () {
      expect(card.data, isA<SteamCardData>());
      final data = card.data! as SteamCardData;
      expect(data.libraryShowcase, hasLength(1));
      expect(data.libraryShowcase[0].appId, 730);
      expect(data.libraryShowcase[0].title, 'CS2');
      expect(data.libraryShowcase[0].hours, 540);
      expect(data.recentGames, hasLength(1));
      expect(data.recentGames[0].appId, 730);
      expect(data.recentGames[0].hours2Weeks, 12);
    });
  });

  group('gameCardFromDto — schema_version fallback', () {
    test('unknown schema_version (> 1) → envelope only, data is null', () {
      final raw = Map<String, dynamic>.from(_steamWidgetData);
      raw['schema_version'] = 99;
      final card = gameCardFromDto(GameCardDto.fromJson(raw));

      expect(card.schemaVersion, 99);
      expect(card.data, isNull);
      // Envelope fields still parsed.
      expect(card.title, 'TestUser');
      expect(card.stats, hasLength(2));
    });
  });

  group('gameCardFromDto — absent data slots', () {
    test('absent library_showcase / recent_games → empty lists', () {
      final raw = Map<String, dynamic>.from(_steamWidgetData);
      raw['data'] = <String, dynamic>{};
      final card = gameCardFromDto(GameCardDto.fromJson(raw));

      expect(card.data, isA<SteamCardData>());
      final data = card.data! as SteamCardData;
      expect(data.libraryShowcase, isEmpty);
      expect(data.recentGames, isEmpty);
    });

    test('null data block → data is null', () {
      final raw = Map<String, dynamic>.from(_steamWidgetData);
      raw.remove('data');
      final card = gameCardFromDto(GameCardDto.fromJson(raw));

      expect(card.data, isNull);
    });
  });

  group('gameCardFromDto — unknown platform', () {
    test('throws FormatException for an unknown platform wire value', () {
      final raw = Map<String, dynamic>.from(_steamWidgetData);
      raw['platform'] = 'unknown_platform';

      expect(
        () => gameCardFromDto(GameCardDto.fromJson(raw)),
        throwsFormatException,
      );
    });
  });
}
