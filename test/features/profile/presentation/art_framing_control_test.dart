import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/core/theme/personalization_tokens.dart';
import 'package:featgg/src/features/profile/domain/art_framing.dart';
import 'package:featgg/src/features/profile/domain/profile_archetype.dart';
import 'package:featgg/src/features/profile/presentation/art_framing_control.dart';
import 'package:featgg/src/features/profile/presentation/personalization_card_shell.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _artUrl = 'https://cdn.test/cover.jpg';
const _cardWidth = 300.0;

/// Mounts art cards in a scrolling page, which is the only place they ever
/// render. A drag control on a card competes with the page's own scrolling, so
/// a harness without the scroll view proves nothing about the gesture.
///
/// Without [onChanged] there is no editing scope, which is the visitor's copy
/// of the same cards.
Widget _page({
  ArtFraming framing = ArtFraming.center,
  Future<bool> Function(String, ArtFraming)? onChanged,
  ProfileCardSize size = ProfileCardSize.full,
  String? art = _artUrl,
  ScrollController? controller,
  int cards = 4,
}) {
  // The column the profile renders in. Bounded here rather than per card: a
  // sliver hands its children the viewport's width whatever they ask for, so a
  // card sized from the inside would silently be the full screen instead.
  final list = SizedBox(
    width: _cardWidth,
    child: ListView(
      controller: controller,
      children: [
        for (var i = 0; i < cards; i++)
          PersonalizationCardShell(
            archetype: ProfileArchetype.art,
            size: size,
            art: art,
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
              : ArtFramingScope(onChanged: onChanged, child: list),
        ),
      ),
    ),
  );
}

/// The alignment the first card's art is actually painting with.
Alignment _paintedAlignment(WidgetTester tester) => tester
    .widget<CachedNetworkImage>(find.byType(CachedNetworkImage).first)
    .alignment;

/// Drives a pointer the way a finger does — many small moves — because a
/// gesture that has to win an arena resolves on the movement between events,
/// not on the total. A single synthetic move never gets past the slop.
Future<void> _swipe(
  WidgetTester tester,
  Offset total, {
  bool hold = false,
  int steps = 20,
}) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(ArtFramingGesture).first),
  );
  if (hold) {
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 20));
  }
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(total / steps.toDouble());
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
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

  group('living in a scrolling page', () {
    testWidgets('an ordinary vertical swipe scrolls, it does not reframe', (
      tester,
    ) async {
      final written = <ArtFraming>[];
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _page(
          controller: controller,
          onChanged: (_, f) async {
            written.add(f);
            return true;
          },
        ),
      );

      await _swipe(tester, const Offset(0, -200));

      expect(controller.offset, greaterThan(0));
      expect(written, isEmpty);
    });

    testWidgets('a held swipe reframes, it does not scroll', (tester) async {
      // Both axes, which is the whole reason the hold is there: without it the
      // page wins every vertical drag and the owner can only move art sideways.
      final written = <ArtFraming>[];
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _page(
          controller: controller,
          onChanged: (_, f) async {
            written.add(f);
            return true;
          },
        ),
      );

      await _swipe(tester, const Offset(0, -100), hold: true);

      expect(controller.offset, 0);
      expect(written, hasLength(1));
      expect(written.single.y, greaterThan(0.5));
    });

    testWidgets('a held sideways swipe reframes too', (tester) async {
      final written = <ArtFraming>[];
      await tester.pumpWidget(
        _page(
          onChanged: (_, f) async {
            written.add(f);
            return true;
          },
        ),
      );

      await _swipe(tester, const Offset(_cardWidth / 4, 0), hold: true);

      expect(written.single.x, closeTo(0.25, 0.01));
    });
  });

  group('the write', () {
    testWidgets('names the widget it belongs to', (tester) async {
      final ids = <String>[];
      await tester.pumpWidget(
        _page(
          onChanged: (id, _) async {
            ids.add(id);
            return true;
          },
        ),
      );

      await _swipe(tester, const Offset(60, 0), hold: true);

      expect(ids, ['w-0']);
    });

    testWidgets('a drag that ends where it started writes nothing', (
      tester,
    ) async {
      final written = <ArtFraming>[];
      await tester.pumpWidget(
        _page(
          onChanged: (_, f) async {
            written.add(f);
            return true;
          },
        ),
      );

      await _swipe(tester, Offset.zero, hold: true);

      expect(written, isEmpty);
    });

    testWidgets('cannot push the picture out of its own frame', (tester) async {
      final written = <ArtFraming>[];
      await tester.pumpWidget(
        _page(
          onChanged: (_, f) async {
            written.add(f);
            return true;
          },
        ),
      );

      await _swipe(
        tester,
        const Offset(-_cardWidth * 4, -_cardWidth * 4),
        hold: true,
      );

      expect(written.single, const ArtFraming(x: 1, y: 1));
    });

    testWidgets('a second drag waits for the first, so the last one wins', (
      tester,
    ) async {
      // Two unrestricted writes can land out of order, and then the framing the
      // owner moved off is the one that sticks.
      final written = <ArtFraming>[];
      final gate = Completer<void>();
      await tester.pumpWidget(
        _page(
          onChanged: (_, f) async {
            written.add(f);
            await gate.future;
            return true;
          },
        ),
      );

      await _swipe(tester, const Offset(30, 0), hold: true);
      expect(written, hasLength(1));

      await _swipe(tester, const Offset(30, 0), hold: true);
      expect(written, hasLength(1), reason: 'the first write is still running');

      gate.complete();
      await tester.pumpAndSettle();

      expect(written, hasLength(2));
      expect(written.last.x, lessThan(written.first.x));
    });

    testWidgets('a rejected framing does not stay on the card', (tester) async {
      // Nothing else would ever take it down: the stored value never changed,
      // so the card would keep showing a crop nobody has.
      await tester.pumpWidget(_page(onChanged: (_, _) async => false));

      await _swipe(tester, const Offset(60, 0), hold: true);

      expect(_paintedAlignment(tester), Alignment.center);
    });

    testWidgets('a framing that landed stays until the profile catches up', (
      tester,
    ) async {
      await tester.pumpWidget(_page(onChanged: (_, _) async => true));

      await _swipe(tester, const Offset(60, 0), hold: true);

      expect(_paintedAlignment(tester).x, lessThan(0));
    });
  });

  group('outside the editor', () {
    testWidgets('a visitor gets no drag control', (tester) async {
      await tester.pumpWidget(_page());

      expect(find.byType(ArtFramingGesture), findsNothing);
    });

    testWidgets('a visitor still sees the owner framing', (tester) async {
      await tester.pumpWidget(_page(framing: const ArtFraming(x: 1, y: 0)));

      expect(_paintedAlignment(tester), Alignment.topRight);
    });

    testWidgets('a card with no picture offers nothing to drag', (
      tester,
    ) async {
      await tester.pumpWidget(
        _page(art: null, onChanged: (_, _) async => true),
      );

      expect(find.byType(ArtFramingGesture), findsNothing);
    });

    testWidgets('the editor marks a card whose picture can be moved', (
      tester,
    ) async {
      await tester.pumpWidget(_page(onChanged: (_, _) async => true));

      expect(find.byType(ArtFramingBadge), findsWidgets);
    });

    testWidgets('a visitor sees no such mark', (tester) async {
      await tester.pumpWidget(_page());

      expect(find.byType(ArtFramingBadge), findsNothing);
    });
  });
}
