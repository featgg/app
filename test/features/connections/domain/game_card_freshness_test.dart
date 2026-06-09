import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal [GameCard] factory — only [platform] and [lastUpdated] vary.
GameCard _card({required Platform platform, required DateTime lastUpdated}) =>
    GameCard(
      schemaVersion: 1,
      platform: platform,
      title: 'TestUser',
      subtitle: null,
      iconImage: null,
      heroImage: null,
      profileUrl: null,
      stats: const [],
      lastUpdated: lastUpdated,
    );

void main() {
  final now = DateTime.utc(2026, 6, 8);

  group('GameCardFreshness.isStaleAt', () {
    test('WoW card older than 30 days → stale', () {
      final card = _card(
        platform: Platform.wowRetail,
        lastUpdated: now.subtract(const Duration(days: 31)),
      );
      expect(card.isStaleAt(now), isTrue);
    });

    test('WoW card within 30 days → not stale', () {
      final card = _card(
        platform: Platform.wowRetail,
        lastUpdated: now.subtract(const Duration(days: 29)),
      );
      expect(card.isStaleAt(now), isFalse);
    });

    test(
      'WoW card exactly at 30-day boundary → not stale (equal, not greater)',
      () {
        final card = _card(
          platform: Platform.wowRetail,
          lastUpdated: now.subtract(const Duration(days: 30)),
        );
        // difference == threshold, not *greater*, so not stale.
        expect(card.isStaleAt(now), isFalse);
      },
    );

    test('non-WoW card older than 30 days → never stale', () {
      for (final platform in [
        Platform.steam,
        Platform.minecraftHypixel,
        Platform.retroachievements,
        Platform.leagueOfLegends,
        Platform.chess,
        Platform.gw2,
      ]) {
        final card = _card(
          platform: platform,
          lastUpdated: now.subtract(const Duration(days: 365)),
        );
        expect(
          card.isStaleAt(now),
          isFalse,
          reason: '${platform.name} should never be freshness-gated',
        );
      }
    });

    test('kCardStaleThreshold is 30 days', () {
      expect(kCardStaleThreshold, const Duration(days: 30));
    });
  });
}
