import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/rarest_achievement_value_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

GameCard _card(Platform platform, CardData? data) => GameCard(
  schemaVersion: 1,
  platform: platform,
  title: '${platform.name}-card',
  subtitle: null,
  iconImage: null,
  heroImage: null,
  profileUrl: null,
  stats: const [],
  lastUpdated: DateTime.utc(2026, 6, 1),
  data: data,
);

GameCard _steam({RarestAchievement? rarest}) => _card(
  Platform.steam,
  SteamCardData(
    libraryShowcase: const [],
    recentGames: const [],
    rarestAchievement: rarest,
  ),
);

const _badgeUrl = 'https://cdn.test/badge.jpg';
const _gameArtUrl = 'https://cdn.test/capsule.jpg';

RarestAchievement _rarest({
  String name = 'Ashes to Ashes',
  String game = 'CS2',
  num rarityPct = 0.31,
  String rarityBasis = kRarityBasisGamePlayers,
  String? iconImage = _badgeUrl,
  String? gameIconImage = _gameArtUrl,
}) => RarestAchievement(
  name: name,
  game: game,
  rarityPct: rarityPct,
  rarityBasis: rarityBasis,
  iconImage: iconImage,
  gameIconImage: gameIconImage,
);

void main() {
  group('resolveRarestAchievement', () {
    test('a Steam card carrying the block resolves the achievement, its game '
        'and its rarity', () {
      final resolved = resolveRarestAchievement(_steam(rarest: _rarest()));

      expect(resolved, isNotNull);
      expect(resolved!.name, 'Ashes to Ashes');
      expect(resolved.game, 'CS2');
      expect(resolved.rarityPct, 0.31);
    });

    test("the game's art becomes the card's picture, the badge stays the "
        'icon', () {
      // A mapper that swapped these would bleed a small square badge across the
      // whole card and hide the game art the payload published for the subject.
      final resolved = resolveRarestAchievement(_steam(rarest: _rarest()));

      expect(resolved!.heroImage, _gameArtUrl);
      expect(resolved.iconImage, _badgeUrl);
    });

    test('a null card, a non-Steam card and a Steam card with no data block '
        'resolve to nothing', () {
      expect(resolveRarestAchievement(null), isNull);
      expect(
        resolveRarestAchievement(
          _card(
            Platform.chess,
            const ChessCardData(primaryMode: 'RAPID', ratings: {}),
          ),
        ),
        isNull,
      );
      expect(resolveRarestAchievement(_card(Platform.steam, null)), isNull);
    });

    test('an absent block resolves to nothing', () {
      // Documented and normal: the payload omits the block when no achievement
      // resolved from the games the sync sampled.
      expect(resolveRarestAchievement(_steam()), isNull);
    });

    test('an unnamed achievement or an unnamed game resolves to nothing', () {
      expect(
        resolveRarestAchievement(_steam(rarest: _rarest(name: ''))),
        isNull,
      );
      expect(
        resolveRarestAchievement(_steam(rarest: _rarest(game: ''))),
        isNull,
      );
    });

    test('a rarity outside (0, 100] resolves to nothing', () {
      for (final pct in const <num>[0, -1, 100.1, 1000]) {
        expect(
          resolveRarestAchievement(_steam(rarest: _rarest(rarityPct: pct))),
          isNull,
          reason: '$pct is not a rarity the card can state honestly',
        );
      }
      // The boundary itself is a real rarity: everyone who plays has it.
      expect(
        resolveRarestAchievement(_steam(rarest: _rarest(rarityPct: 100))),
        isNotNull,
      );
    });

    test('the documented basis resolves to its own datum key', () {
      final resolved = resolveRarestAchievement(
        _steam(rarest: _rarest(rarityBasis: kRarityBasisGamePlayers)),
      );

      expect(resolved!.rarityKey, 'rarity_game_players');
      expect(rarityStatKey(kRarityBasisGamePlayers), 'rarity_game_players');
    });

    test('a basis this build does not know still resolves, with the generic '
        'key', () {
      // Additive backend tokens must not blank a shipped card, and the generic
      // key is what keeps the card from claiming a denominator it cannot vouch
      // for.
      final resolved = resolveRarestAchievement(
        _steam(rarest: _rarest(rarityBasis: 'GLOBAL_ACCOUNTS')),
      );

      expect(resolved, isNotNull);
      expect(resolved!.rarityKey, 'rarity');
      expect(rarityStatKey(''), 'rarity');
    });

    test('only Steam publishes achievement rarity, so only Steam is '
        'offered', () {
      expect(kRarestAchievementPlatforms, {Platform.steam});
    });
  });
}
