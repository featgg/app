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
