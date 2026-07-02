import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/showcase_selection.dart';
import 'package:featgg/src/features/profile/domain/showcase_value_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

SteamCardData _steam(List<LibraryShowcaseEntry> entries) =>
    SteamCardData(libraryShowcase: entries, recentGames: const []);

const _cs2 = LibraryShowcaseEntry(
  appId: 730,
  title: 'Counter-Strike 2',
  hours: 1234,
  heroImage: 'https://cdn.example/730/hero.jpg',
);

void main() {
  group('resolveShowcase', () {
    test('resolves the entry matched by gameRef, hours as the hero', () {
      final resolved = resolveShowcase(
        _steam(const [_cs2]),
        const ShowcaseSelection(gameRef: '730'),
      );

      expect(resolved, isNotNull);
      expect(resolved!.title, 'Counter-Strike 2');
      expect(resolved.heroImage, 'https://cdn.example/730/hero.jpg');
      expect(resolved.heroValue, 1234);
      expect(resolved.hero, ShowcaseHeroStat.hours);
    });

    test('passes through a null heroImage (feed image rules)', () {
      final resolved = resolveShowcase(
        _steam(const [
          LibraryShowcaseEntry(appId: 570, title: 'Dota 2', hours: 42),
        ]),
        const ShowcaseSelection(gameRef: '570'),
      );

      expect(resolved, isNotNull);
      expect(resolved!.heroImage, isNull);
      expect(resolved.heroValue, 42);
    });

    test('returns null for a null card (unlinked / loading / errored)', () {
      expect(
        resolveShowcase(null, const ShowcaseSelection(gameRef: '730')),
        isNull,
      );
    });

    test('returns null for an empty selection', () {
      expect(
        resolveShowcase(_steam(const [_cs2]), ShowcaseSelection.empty),
        isNull,
      );
    });

    test('returns null when the referenced game is absent (rotated out)', () {
      expect(
        resolveShowcase(
          _steam(const [_cs2]),
          const ShowcaseSelection(gameRef: '999'),
        ),
        isNull,
      );
    });
  });

  group('formatShowcaseHeroValue', () {
    test('drops the trailing .0 for a whole number', () {
      expect(formatShowcaseHeroValue(1234), '1234');
      expect(formatShowcaseHeroValue(1234.0), '1234');
    });

    test('keeps decimals for a fractional value', () {
      expect(formatShowcaseHeroValue(12.5), '12.5');
    });
  });
}
