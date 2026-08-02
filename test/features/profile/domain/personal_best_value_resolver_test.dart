import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/personal_best_value_resolver.dart';
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

/// A Chess payload whose primary mode is [primaryMode]. The blitz block always
/// carries a *higher* peak than rapid, so a resolver that took the maximum
/// across modes — rather than the mode the payload declares as primary —
/// resolves a different number and the assertions below fail.
GameCard _chess({
  String primaryMode = 'RAPID',
  int best = 2010,
  int current = 1874,
}) => _card(
  Platform.chess,
  ChessCardData(
    primaryMode: primaryMode,
    ratings: {
      'rapid': ChessModeRating(current: current, best: best),
      'blitz': const ChessModeRating(current: 2180, best: 2240),
    },
  ),
);

void main() {
  group('resolvePersonalBest', () {
    test("a Chess card resolves the primary mode's peak, the mode and the live "
        'figure', () {
      final resolved = resolvePersonalBest(_chess());

      expect(resolved, isNotNull);
      // The peak, not the live figure: the card answers with the best ever.
      expect(resolved!.best, 2010);
      // The primary mode's peak, not the highest across modes — blitz peaks
      // higher and is deliberately not the answer.
      expect(resolved.scope, 'RAPID');
      expect(resolved.current, 1874);
    });

    test('a null card, a non-Chess card and a Chess card with no data block '
        'resolve to nothing', () {
      expect(resolvePersonalBest(null), isNull);
      expect(
        resolvePersonalBest(
          _card(
            Platform.steam,
            const SteamCardData(libraryShowcase: [], recentGames: []),
          ),
        ),
        isNull,
      );
      expect(resolvePersonalBest(_card(Platform.chess, null)), isNull);
    });

    test('a primary mode absent from the ratings map resolves to nothing', () {
      // Documented and normal: the payload publishes a subset of the modes.
      expect(resolvePersonalBest(_chess(primaryMode: 'BULLET')), isNull);
    });

    test('an unnamed primary mode resolves to nothing', () {
      // A figure whose subject cannot be named is not a personal best a reader
      // can place, so the card renders its no-data state instead.
      expect(resolvePersonalBest(_chess(primaryMode: '')), isNull);
    });

    test('a peak of zero or below resolves to nothing', () {
      for (final best in const [0, -1]) {
        expect(
          resolvePersonalBest(_chess(best: best)),
          isNull,
          reason: '$best is not a peak the card can state',
        );
      }
      // The guard is a floor, not a blanket: the smallest real peak resolves.
      expect(resolvePersonalBest(_chess(best: 1))!.best, 1);
    });

    test('a peak equal to the live figure still resolves', () {
      // Being at your own best right now is a true answer about the account,
      // not a no-data state.
      final resolved = resolvePersonalBest(_chess(best: 2010, current: 2010));

      expect(resolved, isNotNull);
      expect(resolved!.best, 2010);
      expect(resolved.current, 2010);
    });

    test('only Chess publishes a peak figure today, so only Chess is '
        'offered', () {
      expect(kPersonalBestPlatforms, {Platform.chess});
    });
  });
}
