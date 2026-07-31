import 'package:featgg/src/features/profile/domain/art_framing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the default names the middle of the picture', () {
    expect(ArtFraming.center.x, 0.5);
    expect(ArtFraming.center.y, 0.5);
    expect(ArtFraming.center.isDefault, isTrue);
  });

  test('the default is the picture at the size that covers its frame', () {
    // Nothing stored has to render exactly as it always did, and this is that
    // claim at the value level.
    expect(ArtFraming.center.scale, ArtFraming.coverScale);
    expect(ArtFraming.center.isDefault, isTrue);
  });

  test('a point off the picture is pulled onto its nearest edge', () {
    expect(ArtFraming.clamped(-0.4, 1.9), const ArtFraming(x: 0, y: 1));
  });

  group('the size', () {
    test('a size below the covering one is pulled up to it', () {
      // The floor: below it the frame shows ground the picture does not reach.
      expect(
        ArtFraming.clamped(0.5, 0.5, scale: 0.4).scale,
        ArtFraming.coverScale,
      );
    });

    test('a size past the ceiling is pulled back to it', () {
      expect(
        ArtFraming.clamped(0.5, 0.5, scale: 99).scale,
        ArtFraming.maxScale,
      );
    });

    test('a size that is not a number reads as the covering one', () {
      // Two fingers landing on the same spot produce one of these, and the
      // value is persisted as JSON — neither can reach the wire.
      expect(
        ArtFraming.clamped(0.5, 0.5, scale: double.nan).scale,
        ArtFraming.coverScale,
      );
      expect(
        ArtFraming.clamped(0.5, 0.5, scale: double.infinity).scale,
        ArtFraming.coverScale,
      );
    });

    test('moving the picture keeps the size it was drawn at', () {
      const from = ArtFraming(x: 0.5, y: 0.5, scale: 2);

      expect(from.shifted(dx: 0.1, dy: 0.1).scale, 2);
    });

    test('scaling keeps the point it is anchored on', () {
      const from = ArtFraming(x: 0.25, y: 0.75);

      expect(from.scaledTo(2), const ArtFraming(x: 0.25, y: 0.75, scale: 2));
    });

    test('a scaled picture at the middle is not the default', () {
      // A scale-only choice still has to be dirty, and still has to be written.
      expect(const ArtFraming(x: 0.5, y: 0.5, scale: 2).isDefault, isFalse);
    });

    test('two framings that differ only in size are not equal', () {
      expect(
        const ArtFraming(x: 0.5, y: 0.5, scale: 2),
        isNot(const ArtFraming(x: 0.5, y: 0.5)),
      );
    });
  });

  group('shifting', () {
    test('moves by the fraction given', () {
      const from = ArtFraming(x: 0.5, y: 0.5);

      expect(
        from.shifted(dx: 0.25, dy: -0.1),
        const ArtFraming(x: 0.75, y: 0.4),
      );
    });

    test('stops at the edge instead of running past it', () {
      // What holds the picture inside its own bounds: a long drag ends at the
      // edge of the image, never somewhere beyond it that names nothing.
      const from = ArtFraming(x: 0.9, y: 0.1);

      expect(from.shifted(dx: 4, dy: -4), const ArtFraming(x: 1, y: 0));
    });

    test('a shift of nothing is the same point', () {
      const from = ArtFraming(x: 0.3, y: 0.7);

      expect(from.shifted(dx: 0, dy: 0), from);
    });
  });

  test('two framings of the same point are equal', () {
    // The card list is rebuilt from equality; a framing that compared unequal
    // to itself would redraw every card on every read.
    expect(const ArtFraming(x: 0.2, y: 0.8), const ArtFraming(x: 0.2, y: 0.8));
  });
}
