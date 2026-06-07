import 'package:featgg/src/features/connections/data/link_account_dto.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('linkBodyBuilders', () {
    test('registers Steam and Minecraft (Hypixel)', () {
      expect(linkBodyBuilders.containsKey(Platform.steam), isTrue);
      expect(linkBodyBuilders.containsKey(Platform.minecraftHypixel), isTrue);
    });

    test('Steam builds the documented {platform, remote_id} body', () {
      final body = linkBodyBuilders[Platform.steam]!('steam', {
        'remote_id': '76561197960287930',
      });
      expect(body, {'platform': 'steam', 'remote_id': '76561197960287930'});
    });

    test('Minecraft builds the documented {platform, remote_id} body', () {
      final body = linkBodyBuilders[Platform.minecraftHypixel]!(
        'minecraft_hypixel',
        {'remote_id': 'TestPlayer'},
      );
      expect(body, {
        'platform': 'minecraft_hypixel',
        'remote_id': 'TestPlayer',
      });
    });

    test('registers RetroAchievements', () {
      expect(linkBodyBuilders.containsKey(Platform.retroachievements), isTrue);
    });

    test(
      'RetroAchievements builds the documented {platform, remote_id} body',
      () {
        final body = linkBodyBuilders[Platform.retroachievements]!(
          'retroachievements',
          {'remote_id': 'TestUser'},
        );
        expect(body, {
          'platform': 'retroachievements',
          'remote_id': 'TestUser',
        });
      },
    );

    test('registers League of Legends', () {
      expect(linkBodyBuilders.containsKey(Platform.leagueOfLegends), isTrue);
    });

    test(
      'League of Legends builds the documented {platform, metadata{...}} body',
      () {
        final body = linkBodyBuilders[Platform.leagueOfLegends]!(
          'league_of_legends',
          {'game_name': 'TestPlayer', 'tag_line': 'NA1', 'region': 'na1'},
        );
        expect(body, {
          'platform': 'league_of_legends',
          'metadata': {
            'game_name': 'TestPlayer',
            'tag_line': 'NA1',
            'region': 'na1',
          },
        });
      },
    );

    test('registers WoW (Retail)', () {
      expect(linkBodyBuilders.containsKey(Platform.wowRetail), isTrue);
    });

    test(
      'WoW builds the documented {platform, metadata{region, realm, character}} body',
      () {
        final body = linkBodyBuilders[Platform.wowRetail]!('wow_retail', {
          'region': 'us',
          'realm': 'stormrage',
          'character': 'Thrall',
        });
        expect(body, {
          'platform': 'wow_retail',
          'metadata': {
            'region': 'us',
            'realm': 'stormrage',
            'character': 'Thrall',
          },
        });
      },
    );

    test('chess maps remote_id into the link body', () {
      expect(linkBodyBuilders.containsKey(Platform.chess), isTrue);
      final body = linkBodyBuilders[Platform.chess]!('chess', {
        'remote_id': 'TestPlayer',
      });
      expect(body, {'platform': 'chess', 'remote_id': 'TestPlayer'});
    });
  });
}
