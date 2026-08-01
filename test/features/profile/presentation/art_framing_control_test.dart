import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/core/theme/personalization_tokens.dart';
import 'package:featgg/src/features/profile/domain/art_framing.dart';
import 'package:featgg/src/features/profile/domain/profile.dart';
import 'package:featgg/src/features/profile/domain/profile_archetype.dart';
import 'package:featgg/src/features/profile/presentation/art_framing_control.dart';
import 'package:featgg/src/features/profile/presentation/personalization_card_shell.dart';
import 'package:featgg/src/features/profile/presentation/personalization_theme_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _artUrl = 'https://cdn.test/cover.jpg';

/// The column the cards render in. A full art card is 4:5, so the frame is this
/// wide and a quarter taller.
const _cardWidth = 300.0;
const _frameHeight = _cardWidth / PersonalizationLayout.cardArtFullAspect;

/// Installs a decoded [width]x[height] image and returns the url serving it,
/// the way the golden harness does. Without this no network image ever resolves
/// under `flutter test`, and the control would see every picture as one that
/// failed to load.
///
/// The url is per size on purpose. The image cache outlives a test and refuses
/// to replace an entry it already holds, so a shared url would hand the second
/// test whatever the first one put there — or the failed load from a test that
/// seeded nothing at all.
Future<String> _seedArt(
  WidgetTester tester, {
  required int width,
  required int height,
}) async {
  final url = 'https://cdn.test/${width}x$height.jpg';
  await tester.runAsync(() async {
    final pixels = Uint8List(width * height * 4)
      ..fillRange(0, width * height * 4, 0xFF);
    final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: width,
      height: height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    PaintingBinding.instance.imageCache.putIfAbsent(
      CachedNetworkImageProvider(url),
      () => OneFrameImageStreamCompleter(
        Future<ImageInfo>.value(ImageInfo(image: frame.image)),
      ),
    );
  });
  return url;
}

/// The editor's half of the contract: owns which card is in framing mode, and
/// holds the page still while one is — both halves, because the second is what
/// makes the drag reachable at all. A drag on a card and a scroll of the page
/// are the same gesture and the page wins the contest, so the mode takes the
/// page out of it rather than competing.
class _EditorScope extends StatefulWidget {
  const _EditorScope({
    required this.onChanged,
    required this.controller,
    required this.builder,
  });

  final void Function(String, ArtFraming) onChanged;
  final ScrollController? controller;
  final Widget Function(ScrollPhysics? physics) builder;

  @override
  State<_EditorScope> createState() => _EditorScopeState();
}

class _EditorScopeState extends State<_EditorScope> {
  String? _active;

  @override
  Widget build(BuildContext context) {
    return ArtFramingScope(
      activeId: _active,
      onActivate: (id) => setState(() => _active = id),
      onChanged: widget.onChanged,
      child: widget.builder(
        _active != null ? const NeverScrollableScrollPhysics() : null,
      ),
    );
  }
}

/// Mounts art cards in a scrolling page, which is the only place they ever
/// render. A drag control on a card competes with the page's own scrolling, so
/// a harness without the scroll view proves nothing about the gesture.
///
/// Without [onChanged] there is no editing scope, which is the visitor's copy
/// of the same cards.
Widget _page({
  ArtFraming framing = ArtFraming.center,
  void Function(String, ArtFraming)? onChanged,
  ProfileCardSize size = ProfileCardSize.full,
  String? art = _artUrl,
  ScrollController? controller,
  int cards = 4,
  ProfileArchetype archetype = ProfileArchetype.art,
  List<PersonalizationStat> stats = const [],
  double width = _cardWidth,
}) {
  // Bounded here rather than per card: a sliver hands its children the
  // viewport's width whatever they ask for, so a card sized from the inside
  // would silently be the full screen instead.
  Widget list(ScrollPhysics? physics) => SizedBox(
    width: width,
    child: ListView(
      controller: controller,
      physics: physics,
      children: [
        for (var i = 0; i < cards; i++)
          PersonalizationCardShell(
            archetype: archetype,
            size: size,
            art: art,
            stats: stats,
            framing: ArtFramingTarget(widgetId: 'w-$i', framing: framing),
          ),
      ],
    ),
  );
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: Scaffold(
      body: Center(
        child: PersonalizationTheme(
          palette: PersonalizationPalette.crimson,
          child: onChanged == null
              ? list(null)
              : _EditorScope(
                  onChanged: onChanged,
                  controller: controller,
                  builder: list,
                ),
        ),
      ),
    ),
  );
}

/// The alignment the first card's art is actually painting with.
Alignment _paintedAlignment(WidgetTester tester) => tester
    .widget<CachedNetworkImage>(find.byType(CachedNetworkImage).first)
    .alignment;

/// Every transform the first card draws inside itself. Empty is the claim that
/// a card at the covering size renders exactly the tree it always did — scoped
/// to the card because the app around it (the route's own transition) carries
/// transforms of its own.
Iterable<Transform> _artTransforms(WidgetTester tester) =>
    tester.widgetList<Transform>(
      find.descendant(
        of: find.byType(PersonalizationCardShell).first,
        matching: find.byType(Transform),
      ),
    );

/// Taps the first card's mark, which is how the owner enters framing mode.
Future<void> _enterMode(WidgetTester tester) async {
  await tester.tap(find.byType(ArtFramingBadge).first);
  await tester.pump();
}

/// Whether some card is in framing mode right now — the confirm mark is only
/// ever drawn on the active card.
Finder get _activeMark => find.byIcon(Icons.check);

/// WCAG 2.x contrast ratio between two opaque colors.
double _contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Drives a pointer the way a finger does — many small moves — because a
/// gesture that has to win an arena resolves on the movement between events,
/// not on the total. A single synthetic move never gets past the slop.
Future<void> _swipe(
  WidgetTester tester,
  Offset total, {
  Offset? from,
  int steps = 20,
}) async {
  final gesture = await tester.startGesture(
    from ?? tester.getCenter(find.byType(CachedNetworkImage).first),
  );
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(total / steps.toDouble());
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  group('what a frame cannot show', () {
    test('a picture the shape of its frame overflows nowhere', () {
      expect(
        artOverflow(frame: const Size(300, 375), image: const Size(400, 500)),
        Size.zero,
      );
    });

    test('a wide picture in a tall frame overflows sideways only', () {
      // Scaled to cover a 300x375 frame, a 1600x900 picture is 666x375.
      final overflow = artOverflow(
        frame: const Size(300, 375),
        image: const Size(1600, 900),
      );

      expect(overflow.width, closeTo(366.6, 0.1));
      expect(overflow.height, 0);
    });

    test('a tall picture in the same frame overflows downwards only', () {
      final overflow = artOverflow(
        frame: const Size(300, 375),
        image: const Size(600, 1600),
      );

      expect(overflow.width, 0);
      expect(overflow.height, closeTo(425, 0.1));
    });

    test('a picture that never loaded overflows nowhere', () {
      expect(
        artOverflow(frame: const Size(300, 375), image: Size.zero),
        Size.zero,
      );
    });

    test('a scaled picture overflows its frame on both axes', () {
      // Covering the frame, a 1600x900 picture is 666.67x375 and hangs off
      // nowhere vertically. Drawn twice that size it is 1333.33x750, so the
      // axis that had no travel gains it.
      final overflow = artOverflow(
        frame: const Size(300, 375),
        image: const Size(1600, 900),
        scale: 2,
      );

      expect(overflow.width, closeTo(1033.3, 0.1));
      expect(overflow.height, closeTo(375, 0.1));
    });
  });

  group('what the frame shows of the picture', () {
    // Slack for the arithmetic only: every bound below is exact in real
    // numbers, so anything larger would be hiding a real escape.
    const slack = 1e-9;
    const frames = [Size(300, 375), Size(139, 174)];
    const images = [Size(1600, 900), Size(400, 500), Size(600, 1600)];
    const points = [
      Offset(0.5, 0.5),
      Offset.zero,
      Offset(1, 0),
      Offset(0, 1),
      Offset(1, 1),
    ];
    const scales = [1.0, 1.5, 3.0];

    test('the frame never shows anything but the picture', () {
      // The one invariant the whole control rests on, stated over every frame,
      // picture, point and size the app can produce.
      for (final frame in frames) {
        for (final image in images) {
          for (final point in points) {
            for (final scale in scales) {
              final framing = ArtFraming(
                x: point.dx,
                y: point.dy,
                scale: scale,
              );
              final rect = artVisibleRect(
                frame: frame,
                image: image,
                framing: framing,
              );
              final where = '$frame / $image / $point / $scale';

              expect(rect.left, greaterThanOrEqualTo(-slack), reason: where);
              expect(rect.top, greaterThanOrEqualTo(-slack), reason: where);
              expect(rect.right, lessThanOrEqualTo(1 + slack), reason: where);
              expect(rect.bottom, lessThanOrEqualTo(1 + slack), reason: where);
            }
          }
        }
      }
    });

    test('a picture drawn below the covering size escapes the frame', () {
      // The adversarial row: proof the assertion above is able to go red. Only
      // the const constructor can produce this — every path an owner or an
      // envelope reaches is clamped to the floor.
      final rect = artVisibleRect(
        frame: const Size(300, 375),
        image: const Size(1600, 900),
        framing: const ArtFraming(x: 0.5, y: 0.5, scale: 0.5),
      );

      expect(rect.bottom, greaterThan(1));
    });

    test('scaling halves what the frame shows', () {
      const frame = Size(300, 375);
      const image = Size(1600, 900);
      final covering = artVisibleRect(
        frame: frame,
        image: image,
        framing: ArtFraming.center,
      );
      final twice = artVisibleRect(
        frame: frame,
        image: image,
        framing: const ArtFraming(x: 0.5, y: 0.5, scale: 2),
      );

      expect(twice.width, closeTo(covering.width / 2, slack));
      expect(twice.height, closeTo(covering.height / 2, slack));
    });

    test('the same choice keeps its meaning when the card changes size', () {
      // Neither the point nor the size is expressed in a frame's own units, so
      // the same stored choice describes the same region of the picture at
      // both card sizes.
      const image = Size(1600, 900);
      const middle = ArtFraming(x: 0.5, y: 0.5, scale: 2);
      const leftEdge = ArtFraming(x: 0, y: 0.5, scale: 2);

      for (final frame in frames) {
        final centred = artVisibleRect(
          frame: frame,
          image: image,
          framing: middle,
        );
        expect(centred.center.dx, closeTo(0.5, slack), reason: '$frame');
        expect(centred.center.dy, closeTo(0.5, slack), reason: '$frame');
        expect(centred.left, greaterThanOrEqualTo(-slack), reason: '$frame');
        expect(centred.right, lessThanOrEqualTo(1 + slack), reason: '$frame');

        final flush = artVisibleRect(
          frame: frame,
          image: image,
          framing: leftEdge,
        );
        expect(flush.left, 0, reason: '$frame');
      }
    });
  });

  group('rendering', () {
    testWidgets('an unframed card crops from the middle, as it always has', (
      tester,
    ) async {
      await tester.pumpWidget(_page());

      expect(_paintedAlignment(tester), Alignment.center);
    });

    testWidgets('a framed card shows the part the owner chose', (tester) async {
      await tester.pumpWidget(_page(framing: const ArtFraming(x: 0, y: 1)));

      expect(_paintedAlignment(tester), Alignment.bottomLeft);
    });

    testWidgets('the picture always fills the frame', (tester) async {
      // The one property reframing must never break: panning moves which part
      // of the picture is visible, it never zooms out far enough to expose the
      // ground behind it.
      await tester.pumpWidget(_page(framing: const ArtFraming(x: 1, y: 0)));

      expect(
        tester
            .widget<CachedNetworkImage>(find.byType(CachedNetworkImage).first)
            .fit,
        BoxFit.cover,
      );
    });

    testWidgets('the same framing survives the card changing size', (
      tester,
    ) async {
      // A point belongs to the picture, not to a frame shape — the reason this
      // is stored as a point and not a rectangle.
      const framing = ArtFraming(x: 0.25, y: 0.75);

      await tester.pumpWidget(_page(framing: framing));
      final full = _paintedAlignment(tester);

      await tester.pumpWidget(
        _page(framing: framing, size: ProfileCardSize.half),
      );

      expect(_paintedAlignment(tester), full);
    });

    testWidgets('a card with no size chosen renders as it always did', (
      tester,
    ) async {
      // On a picture that resolved, so the claim is about the covering size and
      // not about a card that has nothing to wrap yet.
      final url = await _seedArt(tester, width: 1600, height: 900);
      await tester.pumpWidget(
        _page(art: url, framing: const ArtFraming(x: 0.25, y: 0.75)),
      );
      await tester.pump();

      expect(_artTransforms(tester), isEmpty);
    });

    testWidgets('only the picture that arrived is drawn larger', (
      tester,
    ) async {
      // A size describes a picture. While one is loading, and forever if it
      // fails, the card is showing the theme's own ground instead — and the
      // fallback is that ground as the theme draws it, not a gradient blown up
      // and pushed off centre by a setting that was never about it.
      const framing = ArtFraming(x: 0.25, y: 0.75, scale: 2);
      // Seeded before anything is mounted: the default url is served by
      // nothing, so a card pointed at it is the card that never resolves.
      final url = await _seedArt(tester, width: 1600, height: 900);

      await tester.pumpWidget(_page(framing: framing));
      await tester.pump();

      expect(_artTransforms(tester), isEmpty);

      await tester.pumpWidget(_page(framing: framing, art: url));
      await tester.pump();

      expect(_artTransforms(tester), hasLength(1));
    });

    testWidgets(
      'a scaled card draws the picture larger than its frame, about the '
      'framing point',
      (tester) async {
        // What binds the pure geometry to the tree that actually paints: the
        // enlargement is anchored on the very alignment the crop uses, so the
        // two can never disagree about where the picture is held.
        final url = await _seedArt(tester, width: 1600, height: 900);
        await tester.pumpWidget(
          _page(
            art: url,
            framing: const ArtFraming(x: 0.25, y: 0.75, scale: 2),
          ),
        );
        await tester.pump();

        final transform = _artTransforms(tester).single;

        expect(transform.transform.getMaxScaleOnAxis(), closeTo(2, 1e-9));
        expect(transform.alignment, _paintedAlignment(tester));
      },
    );

    testWidgets('the size survives the card changing size', (tester) async {
      const framing = ArtFraming(x: 0.25, y: 0.75, scale: 2);
      final url = await _seedArt(tester, width: 1600, height: 900);

      await tester.pumpWidget(_page(art: url, framing: framing));
      await tester.pump();
      final full = _paintedAlignment(tester);
      final fullScale = _artTransforms(
        tester,
      ).single.transform.getMaxScaleOnAxis();

      await tester.pumpWidget(
        _page(art: url, framing: framing, size: ProfileCardSize.half),
      );
      await tester.pump();

      expect(_paintedAlignment(tester), full);
      expect(
        _artTransforms(tester).single.transform.getMaxScaleOnAxis(),
        fullScale,
      );
    });

    testWidgets('a visitor sees the size the owner chose', (tester) async {
      // No editing scope at all — the read path every visitor gets.
      final url = await _seedArt(tester, width: 1600, height: 900);
      await tester.pumpWidget(
        _page(art: url, framing: const ArtFraming(x: 1, y: 0, scale: 2)),
      );
      await tester.pump();

      expect(
        _artTransforms(tester).single.transform.getMaxScaleOnAxis(),
        closeTo(2, 1e-9),
      );
    });
  });

  group('which cards offer the mark', () {
    testWidgets('a picture larger than its frame does', (tester) async {
      final url = await _seedArt(tester, width: 1600, height: 900);
      await tester.pumpWidget(_page(art: url, onChanged: (_, _) {}));
      await tester.pump();

      expect(find.byType(ArtFramingBadge), findsWidgets);
    });

    testWidgets('a picture the frame does not crop does too', (tester) async {
      // Nothing is cropped, so there is nothing to pan to — but it can still
      // be drawn larger, which is movement enough to earn the mark.
      final url = await _seedArt(tester, width: 400, height: 500);
      await tester.pumpWidget(_page(art: url, onChanged: (_, _) {}));
      await tester.pump();

      expect(find.byType(ArtFramingBadge), findsWidgets);
    });

    testWidgets('a picture that never loaded does not', (tester) async {
      // The card is showing the theme's ground, not a picture. Offering to
      // move it is offering to move nothing.
      await tester.pumpWidget(_page(onChanged: (_, _) {}));
      await tester.pump();

      expect(find.byType(ArtFramingBadge), findsNothing);
    });

    testWidgets('a card with no picture at all does not', (tester) async {
      await tester.pumpWidget(_page(art: null, onChanged: (_, _) {}));

      expect(find.byType(ArtFramingGesture), findsNothing);
    });

    testWidgets('a visitor never gets it, however large the picture', (
      tester,
    ) async {
      final url = await _seedArt(tester, width: 1600, height: 900);
      await tester.pumpWidget(_page(art: url));
      await tester.pump();

      expect(find.byType(ArtFramingBadge), findsNothing);
    });

    testWidgets('a visitor still sees the owner framing', (tester) async {
      await tester.pumpWidget(_page(framing: const ArtFraming(x: 1, y: 0)));

      expect(_paintedAlignment(tester), Alignment.topRight);
    });
  });

  group('the mode', () {
    testWidgets('outside it, a swipe on the card scrolls the page', (
      tester,
    ) async {
      final url = await _seedArt(tester, width: 600, height: 1600);
      final moved = <ArtFraming>[];
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _page(
          art: url,
          controller: controller,
          onChanged: (_, f) => moved.add(f),
        ),
      );
      await tester.pump();

      await _swipe(tester, const Offset(0, -200));

      expect(controller.offset, greaterThan(0));
      expect(moved, isEmpty);
      expect(_activeMark, findsNothing);
    });

    testWidgets('the mark enters it, visibly', (tester) async {
      final url = await _seedArt(tester, width: 600, height: 1600);
      await tester.pumpWidget(_page(art: url, onChanged: (_, _) {}));
      await tester.pump();
      expect(_activeMark, findsNothing);

      await _enterMode(tester);

      expect(_activeMark, findsOneWidget);
    });

    testWidgets(
      'inside it, a plain vertical drag reframes and nothing scrolls',
      (tester) async {
        // The axis the old hold existed for: without ownership the page wins
        // every vertical drag and the owner can only move art sideways.
        final url = await _seedArt(tester, width: 600, height: 1600);
        final moved = <ArtFraming>[];
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _page(
            art: url,
            controller: controller,
            onChanged: (_, f) => moved.add(f),
          ),
        );
        await tester.pump();
        await _enterMode(tester);

        await _swipe(tester, const Offset(0, -100));

        expect(controller.offset, 0);
        expect(moved, hasLength(1));
        expect(moved.single.y, greaterThan(0.5));
      },
    );

    testWidgets('the mark leaves it again', (tester) async {
      final url = await _seedArt(tester, width: 600, height: 1600);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _page(art: url, controller: controller, onChanged: (_, _) {}),
      );
      await tester.pump();
      await _enterMode(tester);

      await tester.tap(_activeMark);
      await tester.pump();

      expect(_activeMark, findsNothing);
      // And the page is a page again.
      await _swipe(tester, const Offset(0, -200));
      expect(controller.offset, greaterThan(0));
    });

    testWidgets('a press outside the card leaves it', (tester) async {
      final url = await _seedArt(tester, width: 600, height: 1600);
      await tester.pumpWidget(_page(art: url, onChanged: (_, _) {}));
      await tester.pump();
      await _enterMode(tester);

      // Off the column entirely — the empty ground beside the cards.
      await tester.tapAt(const Offset(700, 300));
      await tester.pump();

      expect(_activeMark, findsNothing);
    });

    testWidgets('only one card frames at a time', (tester) async {
      final url = await _seedArt(tester, width: 600, height: 1600);
      await tester.pumpWidget(_page(art: url, onChanged: (_, _) {}));
      await tester.pump();
      await _enterMode(tester);

      // Entering on a second card hands the mode over rather than opening a
      // second one. Found by the idle mark rather than by position: the active
      // card draws marks of its own, so counting across cards stops meaning
      // "the next card".
      await tester.tap(find.byIcon(Icons.open_with).first);
      await tester.pump();

      expect(_activeMark, findsOneWidget);
    });

    testWidgets('the mode offers a way to scale without pinching', (
      tester,
    ) async {
      final url = await _seedArt(tester, width: 1600, height: 900);
      await tester.pumpWidget(_page(art: url, onChanged: (_, _) {}));
      await tester.pump();
      expect(find.byIcon(Icons.zoom_in), findsNothing);
      expect(find.byIcon(Icons.zoom_out), findsNothing);

      await _enterMode(tester);

      expect(find.byIcon(Icons.zoom_in), findsOneWidget);
      expect(find.byIcon(Icons.zoom_out), findsOneWidget);
    });

    testWidgets('a press on the enlarge mark scales the picture and records '
        'it', (tester) async {
      final url = await _seedArt(tester, width: 1600, height: 900);
      final moved = <ArtFraming>[];
      await tester.pumpWidget(
        _page(art: url, onChanged: (_, f) => moved.add(f)),
      );
      await tester.pump();
      await _enterMode(tester);

      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pump();

      expect(moved, hasLength(1));
      expect(moved.single.scale, greaterThan(ArtFraming.coverScale));
      expect(moved.single.x, 0.5);
      expect(moved.single.y, 0.5);
    });

    testWidgets('presses stop at the ceiling', (tester) async {
      final url = await _seedArt(tester, width: 1600, height: 900);
      final moved = <ArtFraming>[];
      await tester.pumpWidget(
        _page(art: url, onChanged: (_, f) => moved.add(f)),
      );
      await tester.pump();
      await _enterMode(tester);

      for (var i = 0; i < 10; i++) {
        await tester.tap(find.byIcon(Icons.zoom_in), warnIfMissed: false);
        await tester.pump();
      }

      expect(moved.last.scale, ArtFraming.maxScale);
      final reached = moved.length;

      await tester.tap(find.byIcon(Icons.zoom_in), warnIfMissed: false);
      await tester.pump();

      expect(moved, hasLength(reached));
    });

    testWidgets('at the covering size the reduce mark is inert', (
      tester,
    ) async {
      final url = await _seedArt(tester, width: 1600, height: 900);
      final moved = <ArtFraming>[];
      await tester.pumpWidget(
        _page(art: url, onChanged: (_, f) => moved.add(f)),
      );
      await tester.pump();
      await _enterMode(tester);

      await tester.tap(find.byIcon(Icons.zoom_out), warnIfMissed: false);
      await tester.pump();

      expect(moved, isEmpty);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.zoom_out)).color,
        PersonalizationPalette.crimson.muted,
      );
    });

    testWidgets('reducing returns the picture to the size that covers the '
        'frame', (tester) async {
      // The path back to a row with no framing key at all.
      final url = await _seedArt(tester, width: 1600, height: 900);
      final moved = <ArtFraming>[];
      await tester.pumpWidget(
        _page(art: url, onChanged: (_, f) => moved.add(f)),
      );
      await tester.pump();
      await _enterMode(tester);

      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byIcon(Icons.zoom_in));
        await tester.pump();
      }
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byIcon(Icons.zoom_out));
        await tester.pump();
      }

      expect(moved.last, ArtFraming.center);
      expect(moved.last.isDefault, isTrue);
    });

    testWidgets('a pinch scales the picture', (tester) async {
      final url = await _seedArt(tester, width: 1600, height: 900);
      final moved = <ArtFraming>[];
      await tester.pumpWidget(
        _page(art: url, onChanged: (_, f) => moved.add(f)),
      );
      await tester.pump();
      await _enterMode(tester);

      // Small steps with a pump between, because a recognizer resolves on the
      // movement between events; a single synthetic jump never clears the
      // slop. Started clear of the marks on the right edge.
      final centre = tester.getCenter(
        find.byType(PersonalizationCardShell).first,
      );
      final left = await tester.startGesture(centre - const Offset(20, 0));
      final right = await tester.startGesture(centre + const Offset(20, 0));
      for (var i = 0; i < 10; i++) {
        await left.moveBy(const Offset(-4, 0));
        await right.moveBy(const Offset(4, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await left.up();
      await right.up();
      await tester.pumpAndSettle();

      expect(moved, isNotEmpty);
      expect(moved.last.scale, greaterThan(ArtFraming.coverScale));
    });

    testWidgets('the marks fit the narrowest card the editor can show', (
      tester,
    ) async {
      // The width a half card takes in the narrowest column the editor draws.
      const narrow =
          (PersonalizationLayout.columnMinWidth -
              2 * PersonalizationLayout.columnSidePadding -
              PersonalizationLayout.rowGap) /
          2;
      final url = await _seedArt(tester, width: 1600, height: 900);
      await tester.pumpWidget(
        _page(
          art: url,
          onChanged: (_, _) {},
          size: ProfileCardSize.half,
          width: narrow,
        ),
      );
      await tester.pump();

      await _enterMode(tester);

      expect(tester.takeException(), isNull);
    });
  });

  group('the drag', () {
    testWidgets('moves the picture a pixel for every pixel of finger', (
      tester,
    ) async {
      // What makes the control feel like dragging the picture rather than
      // driving it. A 1600x900 picture covering this frame hangs off the sides
      // by a known amount, so a quarter of that is a quarter of the travel.
      final url = await _seedArt(tester, width: 1600, height: 900);
      final moved = <ArtFraming>[];
      await tester.pumpWidget(
        _page(art: url, onChanged: (_, f) => moved.add(f)),
      );
      await tester.pump();
      await _enterMode(tester);

      final overflow = artOverflow(
        frame: const Size(_cardWidth, _frameHeight),
        image: const Size(1600, 900),
      );
      await _swipe(tester, Offset(overflow.width / 4, 0));

      expect(moved.single.x, closeTo(0.25, 0.01));
      expect(moved.single.y, 0.5);
    });

    testWidgets('names the widget it belongs to', (tester) async {
      final url = await _seedArt(tester, width: 1600, height: 900);
      final ids = <String>[];
      await tester.pumpWidget(
        _page(art: url, onChanged: (id, _) => ids.add(id)),
      );
      await tester.pump();
      await _enterMode(tester);

      await _swipe(tester, const Offset(60, 0));

      expect(ids, ['w-0']);
    });

    testWidgets('a drag that ends where it started reports nothing', (
      tester,
    ) async {
      final url = await _seedArt(tester, width: 1600, height: 900);
      final moved = <ArtFraming>[];
      await tester.pumpWidget(
        _page(art: url, onChanged: (_, f) => moved.add(f)),
      );
      await tester.pump();
      await _enterMode(tester);

      await _swipe(tester, Offset.zero);

      expect(moved, isEmpty);
    });

    testWidgets('cannot push the picture out of its own frame', (tester) async {
      final url = await _seedArt(tester, width: 1600, height: 900);
      final moved = <ArtFraming>[];
      await tester.pumpWidget(
        _page(art: url, onChanged: (_, f) => moved.add(f)),
      );
      await tester.pump();
      await _enterMode(tester);

      await _swipe(tester, const Offset(-_cardWidth * 8, 0));

      expect(moved.single.x, 1);
    });

    testWidgets('an axis with nothing cropped does not move', (tester) async {
      // A wide picture in a tall frame hangs off the sides and nowhere else.
      // Dragging up must not pretend otherwise.
      final url = await _seedArt(tester, width: 1600, height: 900);
      final moved = <ArtFraming>[];
      await tester.pumpWidget(
        _page(art: url, onChanged: (_, f) => moved.add(f)),
      );
      await tester.pump();
      await _enterMode(tester);

      await _swipe(tester, const Offset(0, -80));

      expect(moved, isEmpty);
    });

    testWidgets('at a larger size the drag still tracks the finger', (
      tester,
    ) async {
      // The travel grows with the picture, so the divisor has to be the
      // overflow at the size being drawn now — not the covering one.
      final url = await _seedArt(tester, width: 1600, height: 900);
      final moved = <ArtFraming>[];
      await tester.pumpWidget(
        _page(art: url, onChanged: (_, f) => moved.add(f)),
      );
      await tester.pump();
      await _enterMode(tester);
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byIcon(Icons.zoom_in));
        await tester.pump();
      }

      final overflow = artOverflow(
        frame: const Size(_cardWidth, _frameHeight),
        image: const Size(1600, 900),
        scale: 2,
      );
      await _swipe(
        tester,
        Offset(overflow.width / 4, 0),
        from: tester.getCenter(find.byType(PersonalizationCardShell).first),
      );

      expect(moved.last.scale, 2);
      expect(moved.last.x, closeTo(0.25, 0.01));
    });

    testWidgets('an axis the frame does not crop moves once the picture is '
        'scaled', (tester) async {
      // The case the whole change exists for: a wide picture in a tall frame
      // has no vertical travel at all until it is drawn larger.
      final url = await _seedArt(tester, width: 1600, height: 900);
      final moved = <ArtFraming>[];
      await tester.pumpWidget(
        _page(art: url, onChanged: (_, f) => moved.add(f)),
      );
      await tester.pump();
      await _enterMode(tester);

      await _swipe(tester, const Offset(0, -80));
      expect(moved, isEmpty);

      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pump();
      moved.clear();

      await _swipe(tester, const Offset(0, -80));

      expect(moved, hasLength(1));
      expect(moved.single.y, greaterThan(0.5));
    });

    testWidgets('the picture holds where the finger left it', (tester) async {
      final url = await _seedArt(tester, width: 1600, height: 900);
      await tester.pumpWidget(_page(art: url, onChanged: (_, _) {}));
      await tester.pump();
      await _enterMode(tester);

      await _swipe(tester, const Offset(60, 0));

      expect(_paintedAlignment(tester).x, lessThan(0));
    });
  });

  group('a card that also answers with a number', () {
    // Every picture card except Art draws a number over its own art, behind a
    // gradient that keeps the number legible. Framing reached only Art because
    // both were stacked above the control: the gradient washed the mark out and
    // the number took the press. The harness had only ever mounted Art.
    const stats = [PersonalizationStat(value: '412', label: 'STEAM HOURS')];

    Future<void> pumpCard(
      WidgetTester tester, {
      void Function(String, ArtFraming)? onChanged,
    }) async {
      final url = await _seedArt(tester, width: 1600, height: 900);
      await tester.pumpWidget(
        _page(
          art: url,
          archetype: ProfileArchetype.platform,
          stats: stats,
          onChanged: onChanged,
        ),
      );
      await tester.pump();
    }

    testWidgets('draws its number and offers the mark', (tester) async {
      await pumpCard(tester, onChanged: (_, _) {});

      expect(find.text('412'), findsWidgets);
      expect(find.byType(ArtFramingBadge), findsWidgets);
    });

    testWidgets('shows the mark above what is drawn over the picture', (
      tester,
    ) async {
      // Painted under the gradient the mark is still found, just unreadable —
      // so being present proves nothing. What proves it is being last.
      await pumpCard(tester, onChanged: (_, _) {});

      final painted = find
          .descendant(
            of: find.byType(PersonalizationCardShell).first,
            matching: find.byWidgetPredicate((w) => true),
          )
          .evaluate()
          .toList();
      final badge = painted.indexWhere((e) => e.widget is ArtFramingBadge);
      final scrim = painted.indexWhere((e) => e.widget is DecoratedBox);

      expect(badge, greaterThan(scrim));
    });

    testWidgets('in the mode, a drag over the number moves the picture', (
      tester,
    ) async {
      // The corner the number occupies is the one a finger reaches for on a
      // card whose top half is the picture.
      final moved = <ArtFraming>[];
      await pumpCard(tester, onChanged: (_, f) => moved.add(f));
      await _enterMode(tester);

      final card = tester.getRect(find.byType(PersonalizationCardShell).first);
      await _swipe(
        tester,
        const Offset(80, 0),
        from: Offset(card.left + 40, card.bottom - 20),
      );

      expect(moved, hasLength(1));
      expect(moved.single.x, lessThan(0.5));
    });

    testWidgets('a visitor gets no mark on it either', (tester) async {
      await pumpCard(tester);

      expect(find.byType(ArtFramingBadge), findsNothing);
      expect(find.text('412'), findsWidgets);
    });
  });

  group('the confirm mark', () {
    // The confirm is the one mark painted on the accent itself, so its glyph is
    // the only one whose legibility depends on the theme. A glyph the reader
    // cannot see leaves the mark an empty square with no way out of the mode.
    for (final theme in ProfileTheme.values) {
      testWidgets('${theme.name} draws its glyph against its own fill', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: PersonalizationTheme(
              palette: paletteForTheme(theme),
              child: ArtFramingBadge(
                icon: Icons.check,
                filled: true,
                label: 'confirm',
                onTap: () {},
              ),
            ),
          ),
        );

        final fill =
            (tester
                        .widget<Container>(
                          find.descendant(
                            of: find.byType(ArtFramingBadge),
                            matching: find.byType(Container),
                          ),
                        )
                        .decoration!
                    as BoxDecoration)
                .color!;
        final glyph = tester
            .widget<Icon>(
              find.descendant(
                of: find.byType(ArtFramingBadge),
                matching: find.byType(Icon),
              ),
            )
            .color!;

        expect(
          _contrastRatio(glyph, fill),
          greaterThanOrEqualTo(3.0),
          reason: 'confirm glyph on the ${theme.name} accent',
        );
      });
    }
  });
}
