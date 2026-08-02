import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/main_value_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

GameCard _card(Platform platform, {CardData? data, String title = 'card'}) =>
    GameCard(
      schemaVersion: 1,
      platform: platform,
      title: title,
      subtitle: null,
      iconImage: null,
      heroImage: null,
      profileUrl: null,
      stats: const [],
      lastUpdated: DateTime.utc(2026, 6, 1),
      data: data,
    );

// Fixture-controlled art urls — structural, asserted by value, never copy.
const _portraitA = 'https://cdn.test/champion-a.jpg';
const _portraitB = 'https://cdn.test/champion-b.jpg';
const _iconA = 'https://cdn.test/champion-a-icon.png';

CardStat? _stat(ResolvedMain r, String key) {
  for (final s in r.stats) {
    if (s.key == key) return s;
  }
  return null;
}

LibraryShowcaseEntry _entry(int appId, {required num hours}) =>
    LibraryShowcaseEntry(appId: appId, title: 'Game $appId', hours: hours);

WowProfile _wowProfile({int ilvlAvg = 480}) => WowProfile(
  race: 'Orc',
  faction: 'HORDE',
  className: 'Warrior',
  level: 80,
  ilvlAvg: ilvlAvg,
  ilvlEquipped: ilvlAvg,
);

Gw2Character _gw2Char(
  String name, {
  required bool isMain,
  String prof = 'GUARDIAN',
}) => Gw2Character(
  name: name,
  race: 'Human',
  profession: prof,
  level: 80,
  deaths: 0,
  hoursPlayed: 100,
  isMain: isMain,
);

void main() {
  group('resolveMain — Steam', () {
    test('the top game by hours → its title and hours_played', () {
      final resolved = resolveMain(
        _card(
          Platform.steam,
          data: SteamCardData(
            libraryShowcase: [_entry(1, hours: 100), _entry(2, hours: 900)],
            recentGames: const [],
          ),
        ),
      );

      expect(resolved, isNotNull);
      expect(resolved!.title, 'Game 2');
      expect(_stat(resolved, 'hours_played')?.value, 900);
    });

    test('an empty library → null (no-data omit)', () {
      final resolved = resolveMain(
        _card(
          Platform.steam,
          data: const SteamCardData(libraryShowcase: [], recentGames: []),
        ),
      );
      expect(resolved, isNull);
    });

    test('the top game carries its hero_image into ResolvedMain', () {
      final resolved = resolveMain(
        _card(
          Platform.steam,
          data: const SteamCardData(
            libraryShowcase: [
              LibraryShowcaseEntry(appId: 1, title: 'Game 1', hours: 100),
              LibraryShowcaseEntry(
                appId: 2,
                title: 'Game 2',
                hours: 900,
                heroImage: 'https://cdn.test/cover.jpg',
              ),
            ],
            recentGames: [],
          ),
        ),
      );

      expect(resolved!.heroImage, 'https://cdn.test/cover.jpg');
    });
  });

  group('resolveMain — WoW (Retail)', () {
    test('character name + race/class subtitle + item_level', () {
      final resolved = resolveMain(
        _card(
          Platform.wowRetail,
          title: 'Thrall',
          data: WowRetailCardData(
            profile: _wowProfile(ilvlAvg: 486),
            recentAchievements: const [],
            attribution: 'Blizzard',
          ),
        ),
      );

      expect(resolved, isNotNull);
      expect(resolved!.title, 'Thrall');
      expect(resolved.subtitle, 'Orc Warrior');
      expect(_stat(resolved, 'item_level')?.value, 486);
      // No per-main image field on a non-Steam main → heroImage stays null.
      expect(resolved.heroImage, isNull);
    });

    test('adds mythic_plus_rating when the block carries a rating', () {
      final resolved = resolveMain(
        _card(
          Platform.wowRetail,
          title: 'Thrall',
          data: WowRetailCardData(
            profile: _wowProfile(),
            mythicPlus: const WowMythicPlus(rating: 2500, bestRuns: []),
            recentAchievements: const [],
            attribution: 'Blizzard',
          ),
        ),
      );

      expect(_stat(resolved!, 'mythic_plus_rating')?.value, 2500);
    });
  });

  group('resolveMain — GW2', () {
    test('the main character → name, profession, and account stats', () {
      final resolved = resolveMain(
        _card(
          Platform.gw2,
          data: Gw2CardData(
            account: const Gw2Account(
              accountAgeHours: 1000,
              veterancyYears: 5,
              totalAp: 12000,
              fractalLevel: 100,
            ),
            topCharacters: [
              _gw2Char('Alt', isMain: false, prof: 'WARRIOR'),
              _gw2Char('Chosen', isMain: true, prof: 'GUARDIAN'),
            ],
          ),
        ),
      );

      expect(resolved, isNotNull);
      expect(resolved!.title, 'Chosen');
      expect(resolved.subtitle, 'GUARDIAN');
      expect(_stat(resolved, 'total_ap')?.value, 12000);
      expect(_stat(resolved, 'fractal_level')?.value, 100);
    });

    test(
      'no characters but a mainProfession → title null, subtitle profession',
      () {
        final resolved = resolveMain(
          _card(
            Platform.gw2,
            data: const Gw2CardData(
              mainProfession: 'REVENANT',
              account: Gw2Account(accountAgeHours: 100, veterancyYears: 1),
              topCharacters: [],
            ),
          ),
        );

        expect(resolved, isNotNull);
        expect(resolved!.title, isNull);
        expect(resolved.subtitle, 'REVENANT');
      },
    );

    test('no character, profession, or account stat → null', () {
      final resolved = resolveMain(
        _card(
          Platform.gw2,
          data: const Gw2CardData(
            account: Gw2Account(accountAgeHours: 100, veterancyYears: 1),
            topCharacters: [],
          ),
        ),
      );
      expect(resolved, isNull);
    });
  });

  group('resolveMain — League of Legends', () {
    test('the named top champion is the title, paired with its own points', () {
      final resolved = resolveMain(
        _card(
          Platform.leagueOfLegends,
          data: const LeagueOfLegendsCardData(
            topMastery: [
              LolMasteryEntry(
                championId: 157,
                championName: 'Yasuo',
                level: 7,
                points: 412000,
              ),
              LolMasteryEntry(
                championId: 99,
                championName: 'Jinx',
                level: 6,
                points: 198000,
              ),
            ],
            summoner: LolSummoner(level: 320, profileIconId: 1),
          ),
        ),
      );

      expect(resolved, isNotNull);
      expect(resolved!.title, 'Yasuo');
      expect(_stat(resolved, 'mastery_points')?.value, 412000);
      expect(_stat(resolved, 'summoner_level')?.value, 320);
    });

    test('an unnamed top champion leaves the title null', () {
      final resolved = resolveMain(
        _card(
          Platform.leagueOfLegends,
          data: const LeagueOfLegendsCardData(
            topMastery: [
              LolMasteryEntry(championId: 64, level: 7, points: 250000),
            ],
            summoner: LolSummoner(level: 320, profileIconId: 1),
          ),
        ),
      );

      expect(resolved, isNotNull);
      expect(resolved!.title, isNull);
      expect(_stat(resolved, 'mastery_points')?.value, 250000);
    });

    test("the top champion's own portrait is the main's art", () {
      final resolved = resolveMain(
        _card(
          Platform.leagueOfLegends,
          data: const LeagueOfLegendsCardData(
            topMastery: [
              LolMasteryEntry(
                championId: 157,
                championName: 'Yasuo',
                level: 7,
                points: 412000,
                heroImage: _portraitA,
              ),
              LolMasteryEntry(
                championId: 99,
                championName: 'Jinx',
                level: 6,
                points: 198000,
                heroImage: _portraitB,
              ),
            ],
          ),
        ),
      );

      // Subject, figure and art all come from the same entry.
      expect(resolved, isNotNull);
      expect(resolved!.heroImage, _portraitA);
    });

    test('a top champion with no portrait resolves no art even when it has an '
        'icon', () {
      final resolved = resolveMain(
        _card(
          Platform.leagueOfLegends,
          data: const LeagueOfLegendsCardData(
            topMastery: [
              LolMasteryEntry(
                championId: 157,
                championName: 'Yasuo',
                level: 7,
                points: 412000,
                iconImage: _iconA,
              ),
            ],
          ),
        ),
      );

      // A square icon stretched across a card is not the meaningful image the
      // card asks for, so the card falls to its ground instead.
      expect(resolved, isNotNull);
      expect(resolved!.heroImage, isNull);
    });

    test('empty mastery → null', () {
      final resolved = resolveMain(
        _card(
          Platform.leagueOfLegends,
          data: const LeagueOfLegendsCardData(topMastery: []),
        ),
      );
      expect(resolved, isNull);
    });
  });

  test('resolveMain — Chess → primary-mode title + rating', () {
    final resolved = resolveMain(
      _card(
        Platform.chess,
        data: const ChessCardData(
          primaryMode: 'BLITZ',
          ratings: {'blitz': ChessModeRating(current: 1800, best: 1900)},
        ),
      ),
    );

    expect(resolved, isNotNull);
    expect(resolved!.title, 'BLITZ');
    expect(_stat(resolved, 'rating')?.value, 1800);
  });

  group('resolveMain — unsupported / absent data → null', () {
    test('a null card → null', () => expect(resolveMain(null), isNull));

    test('a RetroAchievements card → null', () {
      final resolved = resolveMain(
        _card(
          Platform.retroachievements,
          data: const RetroAchievementsCardData(
            profile: RetroAchievementsProfile(
              totalPoints: 100,
              truePoints: 200,
              softcorePoints: 0,
              rank: 5,
            ),
            recentGames: [],
          ),
        ),
      );
      expect(resolved, isNull);
    });

    test('a Minecraft card → null', () {
      final resolved = resolveMain(
        _card(
          Platform.minecraftHypixel,
          data: const MinecraftCardData(rank: 'DEFAULT', level: 10, karma: 0),
        ),
      );
      expect(resolved, isNull);
    });
  });
}
