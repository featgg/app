import 'package:featgg/src/features/connections/data/game_card_dto.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture_loader.dart';

/// Contract layer for game cards: recorded real `widget_data` envelopes are
/// replayed through `GameCardDto.fromJson` + `gameCardFromDto`, enforcing the
/// `feed.md` envelope and per-platform `data` shapes.
///
/// Inputs come from recorded fixtures, not invented values. While a fixture is
/// a placeholder the loader fails loudly (red by design).

const _dir = 'test/contract/fixtures/cards';

GameCard _cardFrom(RecordedFixture fixture) =>
    gameCardFromDto(GameCardDto.fromJson(fixture.payload));

void main() {
  group('game cards — recorded contract', () {
    test('steam_v1 → SteamCardData with showcase/recent + parsed envelope', () {
      final card = _cardFrom(loadRecordedFixture('$_dir/steam_v1.json'));
      expect(card.platform, Platform.steam);
      final data = card.data;
      expect(data, isA<SteamCardData>());
      final steam = data! as SteamCardData;
      expect(steam.libraryShowcase, isNotEmpty);
      expect(steam.recentGames, isNotEmpty);
      expect(card.stats, isNotEmpty);
      // lastUpdated parses an ISO-8601 timestamp from the envelope.
      expect(card.lastUpdated, isA<DateTime>());
    });

    test('steam_v1 → the per-game achievement pair is present-together-or-'
        'absent across entries', () {
      final card = _cardFrom(loadRecordedFixture('$_dir/steam_v1.json'));
      final steam = card.data! as SteamCardData;

      LibraryShowcaseEntry entryFor(int appId) =>
          steam.libraryShowcase.firstWhere((e) => e.appId == appId);

      // The fixture carries the pair on the CS2 entry and omits it on Dota.
      final cs2 = entryFor(730);
      expect(cs2.achieved, isNotNull);
      expect(cs2.total, isNotNull);
      expect(cs2.hasAchievements, isTrue);

      final dota = entryFor(570);
      expect(dota.achieved, isNull);
      expect(dota.total, isNull);
      expect(dota.hasAchievements, isFalse);
    });

    test('steam_v1 → perfect_showcase parses into '
        'SteamCardData.perfectShowcase', () {
      final card = _cardFrom(loadRecordedFixture('$_dir/steam_v1.json'));
      final steam = card.data! as SteamCardData;

      expect(steam.perfectShowcase, isNotEmpty);
      final first = steam.perfectShowcase.first;
      expect(first.appId, isA<int>());
      expect(first.title, isNotEmpty);
      expect(first.heroImage, isNotNull);
    });

    test('steam_v1 → the recent entry keeps the cover art it was recorded '
        'with', () {
      final card = _cardFrom(loadRecordedFixture('$_dir/steam_v1.json'));
      final steam = card.data! as SteamCardData;

      // The Recent card bleeds over this url; a mapper that drops the field
      // takes the card's picture with it.
      final entry = steam.recentGames.first;
      expect(entry.heroImage, isNotNull);
      expect(entry.iconImage, isNotNull);
    });

    test('steam_v1 → rarest_achievement parses with its recorded basis '
        'token', () {
      final fixture = loadRecordedFixture('$_dir/steam_v1.json');
      final steam = _cardFrom(fixture).data! as SteamCardData;

      final rarest = steam.rarestAchievement;
      expect(rarest, isNotNull);
      expect(rarest!.name, isNotEmpty);
      expect(rarest.game, isNotEmpty);
      expect(rarest.rarityPct, greaterThan(0));
      // The basis is read from the payload, never assumed: the card labels the
      // rarity by what the recorded token says it is measured against.
      final rawRarest =
          (fixture.payload['data']
                  as Map<String, dynamic>)['rarest_achievement']
              as Map<String, dynamic>;
      expect(rarest.rarityBasis, rawRarest['rarity_basis']);
    });

    test("steam_v1 → the rarest block's game art maps exactly what was "
        'recorded', () {
      final fixture = loadRecordedFixture('$_dir/steam_v1.json');
      final steam = _cardFrom(fixture).data! as SteamCardData;

      final rawRarest =
          (fixture.payload['data']
                  as Map<String, dynamic>)['rarest_achievement']
              as Map<String, dynamic>;
      final rarest = steam.rarestAchievement!;
      // Both slots are pinned to the recording: the card prefers the cover and
      // falls back to the capsule, so a mapper that drops either one changes
      // which picture the card bleeds.
      expect(rarest.gameIconImage, rawRarest['game_icon_image']);
      expect(rarest.gameHeroImage, rawRarest['game_hero_image']);
    });

    test('wow_retail_v1 → WowRetailCardData; best-run completedTimestamp '
        'derives from epoch ms', () {
      final card = _cardFrom(loadRecordedFixture('$_dir/wow_retail_v1.json'));
      expect(card.platform, Platform.wowRetail);
      final data = card.data;
      expect(data, isA<WowRetailCardData>());
      final wow = data! as WowRetailCardData;
      final runs = wow.mythicPlus?.bestRuns ?? const [];
      expect(runs, isNotEmpty);
      // completed_timestamp is epoch milliseconds (NOT ISO) per feed.md; the
      // mapper must read it via fromMillisecondsSinceEpoch, so the parsed
      // DateTime must equal the raw epoch-ms value from the fixture's first run.
      final rawMythicPlus =
          (loadRecordedFixture('$_dir/wow_retail_v1.json').payload['data']
                  as Map<String, dynamic>)['mythic_plus']
              as Map<String, dynamic>;
      final firstRun =
          (rawMythicPlus['best_runs'] as List<dynamic>).first
              as Map<String, dynamic>;
      final epochMs = (firstRun['completed_timestamp'] as num).toInt();
      expect(
        runs.first.completedTimestamp,
        DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true),
      );
    });
  });
}
