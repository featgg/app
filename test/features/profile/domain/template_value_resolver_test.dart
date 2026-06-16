import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/template_value_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

GameCard _card({
  required Platform platform,
  List<CardStat> stats = const [],
  CardData? data,
}) => GameCard(
  schemaVersion: 1,
  platform: platform,
  title: 'card',
  subtitle: null,
  iconImage: null,
  heroImage: null,
  profileUrl: null,
  stats: stats,
  lastUpdated: DateTime.utc(2026, 6, 1),
  data: data,
);

const _rank = LolRank(
  tier: 'GOLD',
  division: 'II',
  lp: 47,
  wins: 10,
  losses: 5,
);

LeagueOfLegendsCardData _lolData({LolRank? rank}) =>
    LeagueOfLegendsCardData(rank: rank, topMastery: const []);

WowRetailCardData _wowData({String className = 'Mage', String race = 'Orc'}) =>
    WowRetailCardData(
      profile: WowProfile(
        race: race,
        faction: 'HORDE',
        className: className,
        level: 70,
        ilvlAvg: 480,
        ilvlEquipped: 478,
      ),
      recentAchievements: const [],
      attribution: 'Data provided by Blizzard',
    );

void main() {
  group('resolveSlot — envelope stats (dataPath == null)', () {
    test('returns the matching stat value and unit', () {
      final card = _card(
        platform: Platform.chess,
        stats: const [CardStat(key: 'rating', value: 1500)],
      );

      final resolved = resolveSlot('chess.rating', card);

      expect(resolved, isNotNull);
      expect(resolved!.value, 1500);
      expect(resolved.item.id, 'chess.rating');
    });

    test('carries the stat unit token when present', () {
      final card = _card(
        platform: Platform.steam,
        stats: const [CardStat(key: 'hours_played', value: 320, unit: 'hours')],
      );

      final resolved = resolveSlot('steam.hours_played', card);

      expect(resolved!.value, 320);
      expect(resolved.unit, 'hours');
    });

    test('returns null for a null card', () {
      expect(resolveSlot('chess.rating', null), isNull);
    });

    test('returns null for a null item id', () {
      expect(resolveSlot(null, _card(platform: Platform.chess)), isNull);
    });

    test('returns null for an unknown item id', () {
      final card = _card(
        platform: Platform.chess,
        stats: const [CardStat(key: 'rating', value: 1500)],
      );
      expect(resolveSlot('not.a.real.id', card), isNull);
    });

    test('returns null when the stat key is absent in the card', () {
      final card = _card(platform: Platform.chess, stats: const []);
      expect(resolveSlot('chess.rating', card), isNull);
    });
  });

  group('resolveSlot — LoL rank (data-block pointer, scope C)', () {
    test('resolves the rank to a composed tier + division + LP string', () {
      final card = _card(
        platform: Platform.leagueOfLegends,
        data: _lolData(rank: _rank),
      );

      final resolved = resolveSlot('league_of_legends.rank', card);

      expect(resolved, isNotNull);
      final value = resolved!.value.toString();
      // Structural assertion — contains the raw tier/division tokens and the LP
      // number, never a localized literal.
      expect(value, contains('GOLD'));
      expect(value, contains('II'));
      expect(value, contains('47'));
    });

    test('soft-omits (null) when the LolRank is null (unranked)', () {
      final card = _card(
        platform: Platform.leagueOfLegends,
        data: _lolData(rank: null),
      );
      expect(resolveSlot('league_of_legends.rank', card), isNull);
    });

    test('soft-omits (null) when card.data is null (absent block)', () {
      final card = _card(platform: Platform.leagueOfLegends, data: null);
      expect(resolveSlot('league_of_legends.rank', card), isNull);
    });

    test('soft-omits (null) for a different CardData subtype', () {
      final card = _card(
        platform: Platform.leagueOfLegends,
        data: const SteamCardData(libraryShowcase: [], recentGames: []),
      );
      expect(resolveSlot('league_of_legends.rank', card), isNull);
    });
  });

  group(
    'resolveSlot — WoW class+race (data-block pointer, #160 composite)',
    () {
      test('resolves to a string containing the raw class and race tokens', () {
        final card = _card(
          platform: Platform.wowRetail,
          data: _wowData(className: 'Mage', race: 'Orc'),
        );

        final resolved = resolveSlot('wow_retail.profile', card);

        expect(resolved, isNotNull);
        final value = resolved!.value.toString();
        // Structural assertion — contains the raw class/race tokens, never a
        // localized literal.
        expect(value, contains('Mage'));
        expect(value, contains('Orc'));
      });

      test('soft-omits (null) when card.data is null (absent block)', () {
        final card = _card(platform: Platform.wowRetail, data: null);
        expect(resolveSlot('wow_retail.profile', card), isNull);
      });

      test('soft-omits (null) for a different CardData subtype', () {
        final card = _card(
          platform: Platform.wowRetail,
          data: const SteamCardData(libraryShowcase: [], recentGames: []),
        );
        expect(resolveSlot('wow_retail.profile', card), isNull);
      });

      test('soft-omits (null) for a null card', () {
        expect(resolveSlot('wow_retail.profile', null), isNull);
      });
    },
  );

  group('resolveSlot — showcase pointer', () {
    test('returns null for a ShowcasePointer item (non-scalar, v1)', () {
      final card = _card(
        platform: Platform.steam,
        data: const SteamCardData(libraryShowcase: [], recentGames: []),
      );
      expect(resolveSlot('steam.library_showcase', card), isNull);
    });
  });

  group('formatLolRank', () {
    test('composes tier, division, and LP into one line', () {
      final out = formatLolRank(_rank);
      expect(out, contains('GOLD'));
      expect(out, contains('II'));
      expect(out, contains('47'));
    });
  });

  group('formatWowClassRace', () {
    test('composes class and race with the separator', () {
      final out = formatWowClassRace(_wowData().profile);
      expect(out, contains('Mage'));
      expect(out, contains('Orc'));
      // The two tokens are joined on one line with the separator between them.
      expect(out, contains('·'));
    });
  });
}
