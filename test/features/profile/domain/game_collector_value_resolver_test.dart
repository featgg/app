import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/game_collector_value_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

LibraryShowcaseEntry _entry(int appId, {required num hours, String? hero}) =>
    LibraryShowcaseEntry(
      appId: appId,
      title: 'Game $appId',
      hours: hours,
      heroImage: hero,
    );

GameCard _card({
  List<CardStat> stats = const [],
  List<LibraryShowcaseEntry> library = const [],
}) => GameCard(
  schemaVersion: 1,
  platform: Platform.steam,
  title: 'steam-card',
  subtitle: null,
  iconImage: null,
  heroImage: null,
  profileUrl: null,
  stats: stats,
  lastUpdated: DateTime.utc(2026, 6, 1),
  data: SteamCardData(libraryShowcase: library, recentGames: const []),
);

const _owned = CardStat(key: 'games_owned', value: 312, unit: 'count');
const _hours = CardStat(key: 'hours_played', value: 1240, unit: 'hours');

void main() {
  group('resolveGameCollector', () {
    test(
      'resolves the count, hours, and the max-hours cover from the card',
      () {
        final resolved = resolveGameCollector(
          _card(
            stats: const [_hours, _owned],
            library: [
              _entry(730, hours: 100, hero: 'https://cdn.example/730.jpg'),
              _entry(570, hours: 400, hero: 'https://cdn.example/570.jpg'),
            ],
          ),
        );

        expect(resolved, isNotNull);
        expect(resolved!.gamesOwned, 312);
        expect(resolved.hoursPlayed, 1240);
        // The cover is the top game by hours (570), not the first entry.
        expect(resolved.heroImage, 'https://cdn.example/570.jpg');
      },
    );

    test('null card → null', () {
      expect(resolveGameCollector(null), isNull);
    });

    test('a card without a games_owned stat → null (the raison d\'être)', () {
      final resolved = resolveGameCollector(
        _card(stats: const [_hours], library: [_entry(730, hours: 100)]),
      );
      expect(resolved, isNull);
    });

    test('a non-numeric games_owned value reads as absent → null', () {
      final resolved = resolveGameCollector(
        _card(
          stats: const [CardStat(key: 'games_owned', value: 'lots')],
        ),
      );
      expect(resolved, isNull);
    });

    test('games_owned present, hours_played absent → hoursPlayed null, still '
        'resolves', () {
      final resolved = resolveGameCollector(
        _card(stats: const [_owned], library: [_entry(730, hours: 100)]),
      );

      expect(resolved, isNotNull);
      expect(resolved!.gamesOwned, 312);
      expect(resolved.hoursPlayed, isNull);
    });

    test('empty library → heroImage null, still resolves', () {
      final resolved = resolveGameCollector(
        _card(stats: const [_owned, _hours]),
      );

      expect(resolved, isNotNull);
      expect(resolved!.gamesOwned, 312);
      expect(resolved.heroImage, isNull);
    });

    test('the max-hours entry cover wins over list order', () {
      final resolved = resolveGameCollector(
        _card(
          stats: const [_owned],
          library: [
            _entry(1, hours: 900, hero: 'https://cdn.example/top.jpg'),
            _entry(2, hours: 10, hero: 'https://cdn.example/low.jpg'),
          ],
        ),
      );

      expect(resolved!.heroImage, 'https://cdn.example/top.jpg');
    });
  });
}
