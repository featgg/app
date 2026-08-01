import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/recent_value_resolver.dart';
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

GameCard _steam({
  List<RecentGameEntry> recent = const [],
  List<LibraryShowcaseEntry> library = const [],
}) => _card(
  Platform.steam,
  SteamCardData(libraryShowcase: library, recentGames: recent),
);

const _coverA = 'https://cdn.test/cover-a.jpg';

void main() {
  group('resolveRecent', () {
    test('the entry with the most recent hours wins, not the first', () {
      final resolved = resolveRecent(
        _steam(
          recent: const [
            RecentGameEntry(appId: 1, title: 'First', hours2Weeks: 3),
            RecentGameEntry(appId: 2, title: 'Most', hours2Weeks: 12),
            RecentGameEntry(appId: 3, title: 'Middle', hours2Weeks: 7),
          ],
        ),
      );

      // The feed documents no ordering for the recent list, so position must
      // not decide the subject — a first-entry read would name "First" here.
      expect(resolved!.title, 'Most');
      expect(
        resolved.stats.first,
        const CardStat(key: 'hours_2weeks', value: 12),
      );
    });

    test('a tie keeps the first entry', () {
      final resolved = resolveRecent(
        _steam(
          recent: const [
            RecentGameEntry(appId: 1, title: 'Earlier', hours2Weeks: 5),
            RecentGameEntry(appId: 2, title: 'Later', hours2Weeks: 5),
          ],
        ),
      );

      // Deterministic tiebreak: the card must not swap subjects between two
      // renders of the same payload.
      expect(resolved!.title, 'Earlier');
    });

    test('an empty recent_games → null', () {
      expect(resolveRecent(_steam()), isNull);
    });

    test('an entry with an empty title → null', () {
      final resolved = resolveRecent(
        _steam(
          recent: const [RecentGameEntry(appId: 1, title: '', hours2Weeks: 40)],
        ),
      );

      // A card whose subject cannot be named does not ship, however large the
      // number beside it.
      expect(resolved, isNull);
    });

    test('an unnamed entry is skipped, a named sibling still resolves', () {
      final resolved = resolveRecent(
        _steam(
          recent: const [
            RecentGameEntry(appId: 1, title: '', hours2Weeks: 40),
            RecentGameEntry(appId: 2, title: 'Named', hours2Weeks: 2),
          ],
        ),
      );

      expect(resolved!.title, 'Named');
    });

    test('zero recent hours still resolves', () {
      final resolved = resolveRecent(
        _steam(
          recent: const [
            RecentGameEntry(appId: 1, title: 'Barely', hours2Weeks: 0),
          ],
        ),
      );

      // Presence in the list is the signal that the game was played recently;
      // the magnitude is not the gate.
      expect(resolved!.title, 'Barely');
      expect(resolved.stats.first.value, 0);
    });

    test("the chosen entry's hero image reaches ResolvedRecent", () {
      final resolved = resolveRecent(
        _steam(
          recent: const [
            RecentGameEntry(
              appId: 1,
              title: 'Arty',
              hours2Weeks: 9,
              heroImage: _coverA,
            ),
          ],
        ),
      );

      // The card bleeds over the recent entry's own cover, not the envelope's.
      expect(resolved!.heroImage, _coverA);
    });

    test('a recent entry with no cover resolves with a null hero image', () {
      final resolved = resolveRecent(
        _steam(
          recent: const [
            RecentGameEntry(appId: 1, title: 'Plain', hours2Weeks: 9),
          ],
        ),
      );

      expect(resolved!.heroImage, isNull);
    });

    test('all-time hours are added only for the same app_id', () {
      final matched = resolveRecent(
        _steam(
          recent: const [
            RecentGameEntry(appId: 730, title: 'CS', hours2Weeks: 12),
          ],
          library: const [
            LibraryShowcaseEntry(appId: 730, title: 'CS', hours: 900),
            LibraryShowcaseEntry(appId: 570, title: 'Dota', hours: 1500),
          ],
        ),
      );

      // Keyed apart from the recent figure: two hour numbers on one card need
      // two labels, and a shared key can only resolve to one.
      expect(matched!.stats, const [
        CardStat(key: 'hours_2weeks', value: 12),
        CardStat(key: 'hours_total', value: 900),
      ]);

      final unmatched = resolveRecent(
        _steam(
          recent: const [
            RecentGameEntry(appId: 730, title: 'CS', hours2Weeks: 12),
          ],
          library: const [
            LibraryShowcaseEntry(appId: 570, title: 'Dota', hours: 1500),
          ],
        ),
      );

      // A supporting stat must explain the hero; an all-time figure for another
      // game explains nothing, so it is absent rather than borrowed.
      expect(unmatched!.stats, const [
        CardStat(key: 'hours_2weeks', value: 12),
      ]);
    });

    test('a non-Steam card and a null card → null', () {
      expect(resolveRecent(null), isNull);
      expect(
        resolveRecent(
          _card(
            Platform.retroachievements,
            const RetroAchievementsCardData(
              profile: RetroAchievementsProfile(
                totalPoints: 1,
                truePoints: 2,
                softcorePoints: 0,
                rank: 5,
              ),
              recentGames: [
                RetroAchievementsRecentGame(
                  title: 'Sonic',
                  console: 'Mega Drive',
                  achieved: 1,
                  total: 2,
                  completionPct: 50,
                ),
              ],
            ),
          ),
        ),
        isNull,
      );
      // A Steam card whose data block is absent resolves to nothing too.
      expect(resolveRecent(_card(Platform.steam, null)), isNull);
    });
  });

  group('kRecentPlatforms', () {
    test('only Steam publishes recent playtime, so only Steam is offered', () {
      expect(kRecentPlatforms, {Platform.steam});
    });
  });
}
