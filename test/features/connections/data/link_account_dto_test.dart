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
  });
}
