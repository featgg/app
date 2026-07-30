import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/core/theme/personalization_tokens.dart';
import 'package:featgg/src/features/profile/domain/art_framing.dart';
import 'package:featgg/src/features/profile/domain/profile_archetype.dart';
import 'package:featgg/src/features/profile/presentation/art_framing_control.dart';
import 'package:featgg/src/features/profile/presentation/personalization_card_shell.dart';
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

/// The editor's half of the contract: owns which card is in framing mode, the
/// way the real editor does, so entering and leaving the mode behaves here as
/// it does in production.
class _EditorScope extends StatefulWidget {
  const _EditorScope({required this.onChanged, required this.child});

  final void Function(String, ArtFraming) onChanged;
  final Widget child;

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
      child: widget.child,
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
}) {
  // Bounded here rather than per card: a sliver hands its children the
  // viewport's width whatever they ask for, so a card sized from the inside
  // would silently be the full screen instead.
  final list = SizedBox(
    width: _cardWidth,
    child: ListView(
      controller: controller,
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
              ? list
              : _EditorScope(onChanged: onChanged, child: list),
        ),
      ),
    ),
  );
}

/// The alignment the first card's art is actually painting with.
Alignment _paintedAlignment(WidgetTester tester) => tester
    .widget<CachedNetworkImage>(find.byType(CachedNetworkImage).first)
    .alignment;

/// Taps the first card's mark, which is how the owner enters framing mode.
Future<void> _enterMode(WidgetTester tester) async {
  await tester.tap(find.byType(ArtFramingBadge).first);
  await tester.pump();
}

/// Whether some card is in framing mode right now — the confirm mark is only
/// ever drawn on the active card.
Finder get _activeMark => find.byIcon(Icons.check);

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
  });

  group('which cards offer the mark', () {
    testWidgets('a picture larger than its frame does', (tester) async {
      final url = await _seedArt(tester, width: 1600, height: 900);
      await tester.pumpWidget(_page(art: url, onChanged: (_, _) {}));
      await tester.pump();

      expect(find.byType(ArtFramingBadge), findsWidgets);
    });

    testWidgets('a picture the shape of its frame does not', (tester) async {
      // Nothing is cropped, so there is nothing to move to. A card that
      // answered the mark with no movement would read as broken.
      final url = await _seedArt(tester, width: 400, height: 500);
      await tester.pumpWidget(_page(art: url, onChanged: (_, _) {}));
      await tester.pump();

      expect(find.byType(ArtFramingBadge), findsNothing);
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
      // second one.
      await tester.tap(find.byType(ArtFramingBadge).at(1));
      await tester.pump();

      expect(_activeMark, findsOneWidget);
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
}
