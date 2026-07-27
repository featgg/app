import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/profile_header_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

GameCard _card(Platform platform, {String? heroImage, String? iconImage}) =>
    GameCard(
      schemaVersion: 1,
      platform: platform,
      title: '${platform.name}-card',
      subtitle: null,
      iconImage: iconImage,
      heroImage: heroImage,
      profileUrl: null,
      stats: const [],
      lastUpdated: DateTime.utc(2026, 6, 1),
    );

void main() {
  group('marks', () {
    test('one per linked platform, in a stable order', () {
      final resolved = resolveProfileHeader({
        Platform.wowRetail: _card(Platform.wowRetail),
        Platform.steam: _card(Platform.steam),
      });

      expect(resolved.platforms, [Platform.steam, Platform.wowRetail]);
    });

    test('a platform with no card is not linked', () {
      final resolved = resolveProfileHeader({
        Platform.steam: _card(Platform.steam),
        Platform.chess: null,
      });

      expect(resolved.platforms, [Platform.steam]);
    });

    test('nothing linked resolves to no marks and no art', () {
      final resolved = resolveProfileHeader(const {});

      expect(resolved.platforms, isEmpty);
      expect(resolved.art, isNull);
    });
  });

  group('chosen art', () {
    test('the owner\'s choice wins over the platform they feature', () {
      final resolved = resolveProfileHeader(
        {
          Platform.steam: _card(Platform.steam, heroImage: 'steam-hero'),
          Platform.wowRetail: _card(Platform.wowRetail, heroImage: 'wow-hero'),
        },
        chosen: Platform.wowRetail,
        featured: Platform.steam,
      );

      expect(resolved.art, 'wow-hero');
    });

    test('a choice that publishes no art falls back rather than blanking', () {
      final resolved = resolveProfileHeader(
        {
          Platform.steam: _card(Platform.steam, heroImage: 'steam-hero'),
          Platform.chess: _card(Platform.chess),
        },
        chosen: Platform.chess,
        featured: Platform.steam,
      );

      expect(resolved.art, 'steam-hero');
    });

    test('a choice naming an unlinked platform falls back', () {
      final resolved = resolveProfileHeader({
        Platform.steam: _card(Platform.steam, heroImage: 'steam-hero'),
      }, chosen: Platform.gw2);

      expect(resolved.art, 'steam-hero');
    });
  });

  group('default art', () {
    test('the featured platform wins over an earlier linked one', () {
      final resolved = resolveProfileHeader({
        Platform.steam: _card(Platform.steam, heroImage: 'steam-hero'),
        Platform.wowRetail: _card(Platform.wowRetail, heroImage: 'wow-hero'),
      }, featured: Platform.wowRetail);

      expect(resolved.art, 'wow-hero');
    });

    test('a featured platform publishing no art loses to one that does', () {
      final resolved = resolveProfileHeader({
        Platform.steam: _card(Platform.steam, heroImage: 'steam-hero'),
        Platform.chess: _card(Platform.chess),
      }, featured: Platform.chess);

      expect(resolved.art, 'steam-hero');
    });

    test('no featured platform falls to the first linked one with art', () {
      final resolved = resolveProfileHeader({
        Platform.chess: _card(Platform.chess),
        Platform.wowRetail: _card(Platform.wowRetail, heroImage: 'wow-hero'),
      });

      expect(resolved.art, 'wow-hero');
    });

    test(
      'a card with only an icon still keeps the header off the gradient',
      () {
        final resolved = resolveProfileHeader({
          Platform.chess: _card(Platform.chess, iconImage: 'chess-icon'),
        });

        expect(resolved.art, 'chess-icon');
      },
    );

    test('the hero image is preferred over the icon of the same card', () {
      final resolved = resolveProfileHeader({
        Platform.steam: _card(
          Platform.steam,
          heroImage: 'steam-hero',
          iconImage: 'steam-icon',
        ),
      });

      expect(resolved.art, 'steam-hero');
    });

    test('linked platforms that publish nothing leave the art null', () {
      final resolved = resolveProfileHeader({
        Platform.chess: _card(Platform.chess),
        Platform.gw2: _card(Platform.gw2),
      });

      expect(resolved.platforms, [Platform.chess, Platform.gw2]);
      expect(resolved.art, isNull);
    });
  });
}
