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
const _cardWidth = 320.0;

/// Mounts an art card at [framing]. Without [onChanged] there is no editing
/// scope, which is the visitor's copy of the same card.
Widget _card({
  ArtFraming framing = ArtFraming.center,
  void Function(String, ArtFraming)? onChanged,
  ProfileCardSize size = ProfileCardSize.full,
  String? art = _artUrl,
}) {
  final Widget card = PersonalizationCardShell(
    archetype: ProfileArchetype.art,
    size: size,
    art: art,
    framing: ArtFramingTarget(widgetId: 'w-1', framing: framing),
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
        child: SizedBox(
          width: _cardWidth,
          child: PersonalizationTheme(
            palette: PersonalizationPalette.crimson,
            child: onChanged == null
                ? card
                : ArtFramingScope(onChanged: onChanged, child: card),
          ),
        ),
      ),
    ),
  );
}

/// The alignment the art layer is actually painting with.
Alignment _paintedAlignment(WidgetTester tester) => tester
    .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
    .alignment;

void main() {
  group('rendering', () {
    testWidgets('an unframed card crops from the middle, as it always has', (
      tester,
    ) async {
      await tester.pumpWidget(_card());

      expect(_paintedAlignment(tester), Alignment.center);
    });

    testWidgets('a framed card shows the part the owner chose', (tester) async {
      await tester.pumpWidget(_card(framing: const ArtFraming(x: 0, y: 1)));

      expect(_paintedAlignment(tester), Alignment.bottomLeft);
    });

    testWidgets('the picture always fills the frame', (tester) async {
      // The one property reframing must never break: panning moves which part
      // of the picture is visible, it never zooms out far enough to expose the
      // ground behind it.
      await tester.pumpWidget(_card(framing: const ArtFraming(x: 1, y: 0)));

      expect(
        tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage)).fit,
        BoxFit.cover,
      );
    });

    testWidgets('the same framing survives the card changing size', (
      tester,
    ) async {
      // A point belongs to the picture, not to a frame shape — the reason this
      // is stored as a point and not a rectangle.
      const framing = ArtFraming(x: 0.25, y: 0.75);

      await tester.pumpWidget(_card(framing: framing));
      final full = _paintedAlignment(tester);

      await tester.pumpWidget(
        _card(framing: framing, size: ProfileCardSize.half),
      );

      expect(_paintedAlignment(tester), full);
    });
  });

  group('the drag', () {
    testWidgets('moves the picture with the finger and persists on release', (
      tester,
    ) async {
      final written = <ArtFraming>[];
      await tester.pumpWidget(
        _card(onChanged: (_, framing) => written.add(framing)),
      );

      // A quarter of the card's width to the right. Dragging the picture right
      // brings the part to its left into view, so the point looked at moves
      // left.
      await tester.drag(
        find.byType(ArtFramingGesture),
        const Offset(_cardWidth / 4, 0),
      );
      await tester.pump();

      expect(written, hasLength(1));
      expect(written.single.x, closeTo(0.25, 0.001));
      expect(written.single.y, 0.5);
    });

    testWidgets('shows the new framing before the write comes back', (
      tester,
    ) async {
      // The picture holds where the finger left it. Snapping back to the old
      // crop for the length of a round trip reads as the drag having failed.
      await tester.pumpWidget(_card(onChanged: (_, _) {}));

      await tester.drag(
        find.byType(ArtFramingGesture),
        const Offset(0, -_cardWidth / 4),
      );
      await tester.pump();

      expect(_paintedAlignment(tester).y, greaterThan(0));
    });

    testWidgets('names the widget it belongs to', (tester) async {
      final ids = <String>[];
      await tester.pumpWidget(_card(onChanged: (id, _) => ids.add(id)));

      await tester.drag(find.byType(ArtFramingGesture), const Offset(40, 0));
      await tester.pump();

      expect(ids, ['w-1']);
    });

    testWidgets('a drag that ends where it started writes nothing', (
      tester,
    ) async {
      final written = <ArtFraming>[];
      await tester.pumpWidget(
        _card(onChanged: (_, framing) => written.add(framing)),
      );

      await tester.drag(find.byType(ArtFramingGesture), Offset.zero);
      await tester.pump();

      expect(written, isEmpty);
    });

    testWidgets('cannot push the picture out of its own frame', (tester) async {
      final written = <ArtFraming>[];
      await tester.pumpWidget(
        _card(onChanged: (_, framing) => written.add(framing)),
      );

      await tester.drag(
        find.byType(ArtFramingGesture),
        const Offset(-_cardWidth * 4, -_cardWidth * 4),
      );
      await tester.pump();

      expect(written.single, const ArtFraming(x: 1, y: 1));
    });
  });

  group('outside the editor', () {
    testWidgets('a visitor gets no drag control', (tester) async {
      await tester.pumpWidget(_card());

      expect(find.byType(ArtFramingGesture), findsNothing);
    });

    testWidgets('a visitor still sees the owner framing', (tester) async {
      await tester.pumpWidget(_card(framing: const ArtFraming(x: 1, y: 0)));

      expect(_paintedAlignment(tester), Alignment.topRight);
    });

    testWidgets('a card with no picture offers nothing to drag', (
      tester,
    ) async {
      await tester.pumpWidget(_card(art: null, onChanged: (_, _) {}));

      expect(find.byType(ArtFramingGesture), findsNothing);
    });
  });
}
