import 'package:featgg/src/core/theme/personalization_tokens.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

PersonalizationPalette _paletteWith(Color accent) => PersonalizationPalette(
  bg: const Color(0xFF000000),
  surface: const Color(0xFF111111),
  surface2: const Color(0xFF222222),
  line: const Color(0xFF333333),
  text: const Color(0xFFFFFFFF),
  muted: const Color(0xFF999999),
  accent: accent,
  accentSoft: const Color(0x22FFFFFF),
  artA: const Color(0xFF444444),
  artB: const Color(0xFF555555),
  artC: const Color(0xFF666666),
  radius: 10,
);

void main() {
  group('header cover', () {
    test('is wide and shallow, so the cards are not pushed off the screen', () {
      // The shape this replaced was taller than the column was wide. Asserting
      // the direction, not the number, so retuning the cover does not redden
      // this — but turning it back into a portrait block does.
      expect(PersonalizationLayout.coverAspect, greaterThan(1));
    });

    test('a cover is a fraction of the column it spans', () {
      const columnWidth = 572.0;
      final coverHeight = columnWidth / PersonalizationLayout.coverAspect;

      expect(coverHeight, lessThan(columnWidth / 2));
    });
  });

  group('PersonalizationTheme', () {
    testWidgets('of returns the injected palette', (tester) async {
      final injected = _paletteWith(const Color(0xFF010203));
      late PersonalizationPalette read;

      await tester.pumpWidget(
        PersonalizationTheme(
          palette: injected,
          child: Builder(
            builder: (context) {
              read = PersonalizationTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(read, injected);
    });

    test('updateShouldNotify fires only when the palette changes', () {
      const child = SizedBox();
      final a = PersonalizationTheme(
        palette: _paletteWith(const Color(0xFFAA0000)),
        child: child,
      );
      final sameAsA = PersonalizationTheme(
        palette: _paletteWith(const Color(0xFFAA0000)),
        child: child,
      );
      final b = PersonalizationTheme(
        palette: _paletteWith(const Color(0xFF0000BB)),
        child: child,
      );

      expect(b.updateShouldNotify(a), isTrue);
      expect(sameAsA.updateShouldNotify(a), isFalse);
    });
  });
}
