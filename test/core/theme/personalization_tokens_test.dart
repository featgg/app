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
  group('heroFrameHeight (spec §4 conditional-fit budget)', () {
    const columnWidth = 572.0;

    test('a tall viewport is bounded by the 4:5 column height (fill)', () {
      // 0.78 * 2000 = 1560 > 572 * 1.25 = 715 → the aspect budget wins.
      expect(
        heroFrameHeight(2000, columnWidth),
        columnWidth * PersonalizationLayout.heroAspectFactor,
      );
    });

    test('a short viewport is bounded by the viewport budget (contain)', () {
      // 0.78 * 600 = 468 < 572 * 1.25 = 715 → the viewport budget wins.
      expect(
        heroFrameHeight(600, columnWidth),
        PersonalizationLayout.heroViewportFactor * 600,
      );
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
