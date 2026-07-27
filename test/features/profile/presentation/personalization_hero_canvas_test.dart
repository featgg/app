import 'package:cached_network_image/cached_network_image.dart';
import 'package:featgg/src/core/theme/personalization_tokens.dart';
import 'package:featgg/src/features/profile/presentation/personalization_hero_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const double _columnWidth = 572;
const String _artUrl = 'https://cdn.test/header-art.jpg';

/// Sizes the render surface to the column width and [screenHeight] so the
/// `MediaQuery`-derived frame budget has real room (a too-short window would
/// clamp the frame and defeat the conditional-fit check).
Future<void> _pump(
  WidgetTester tester, {
  required double screenHeight,
  String? imageUrl,
}) async {
  tester.view.physicalSize = Size(_columnWidth, screenHeight);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: _columnWidth,
          child: PersonalizationTheme(
            palette: PersonalizationPalette.crimson,
            child: PersonalizationHeroCanvas(
              columnWidth: _columnWidth,
              imageUrl: imageUrl,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('conditional fit', () {
    testWidgets('tall viewport: art fills the column width, blur present', (
      tester,
    ) async {
      // 0.78 * 2000 = 1560 > 572 * 1.25 = 715 → the frame is the full 4:5 height
      // and the contained art fills the column width (no visible blurred sides).
      await _pump(tester, screenHeight: 2000);

      final artWidth = tester.getSize(find.byKey(kHeroArtKey)).width;
      expect(artWidth, moreOrLessEquals(_columnWidth, epsilon: 0.5));
      expect(find.byType(ImageFiltered), findsOneWidget);
    });

    testWidgets('short viewport: art is contained (narrower), blur present', (
      tester,
    ) async {
      // 0.78 * 600 = 468 < 715 → the frame shortens, the art is bounded by the
      // frame height and is narrower than the column, so the blurred side-fill
      // is exposed.
      await _pump(tester, screenHeight: 600);

      final artWidth = tester.getSize(find.byKey(kHeroArtKey)).width;
      expect(artWidth, lessThan(_columnWidth));
      expect(find.byType(ImageFiltered), findsOneWidget);
    });
  });

  group('art', () {
    testWidgets('a resolved url paints the art and its blurred copy', (
      tester,
    ) async {
      await _pump(tester, screenHeight: 2000, imageUrl: _artUrl);

      // Both the contained art and the blur-extend fill behind it draw the same
      // image; a fill painted from something else would seam against the art.
      expect(
        find.byWidgetPredicate(
          (w) => w is CachedNetworkImage && w.imageUrl == _artUrl,
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('no url falls back to the theme gradient', (tester) async {
      await _pump(tester, screenHeight: 2000);

      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.byType(DecoratedBox), findsWidgets);
    });
  });
}
