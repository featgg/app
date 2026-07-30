import 'package:featgg/src/features/profile/domain/art_framing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the default names the middle of the picture', () {
    expect(ArtFraming.center.x, 0.5);
    expect(ArtFraming.center.y, 0.5);
    expect(ArtFraming.center.isCenter, isTrue);
  });

  test('a point off the picture is pulled onto its nearest edge', () {
    expect(ArtFraming.clamped(-0.4, 1.9), const ArtFraming(x: 0, y: 1));
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
