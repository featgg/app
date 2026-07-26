import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/profile_archetype.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/showcase_selection.dart';
import 'package:featgg/src/features/profile/presentation/personalization_archetype_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

/// A Milestone card bound to a Steam game. Milestone is the whole art path in
/// one card: a resolved cover fills it edge to edge, no cover degrades it to the
/// drawn motif.
Widget _milestoneCard() => MilestoneCard(
  widget: goldenWidget(
    id: 'guard',
    kind: ProfileWidgetKind.showcase,
    platform: Platform.steam,
    showcaseSelection: const ShowcaseSelection(gameRef: '730'),
  ),
  size: ProfileCardSize.full,
  cardSource: goldenCardSource,
);

Map<Platform, GameCard?> _steamLibrary({String? heroImage}) => {
  Platform.steam: goldenCard(
    Platform.steam,
    data: SteamCardData(
      libraryShowcase: [
        goldenLibraryEntry(
          appId: 730,
          title: 'Counter-Strike',
          hours: 1200,
          heroImage: heroImage,
        ),
      ],
      recentGames: const [],
    ),
  ),
};

/// Pixels actually painted under each key, so a glyph assertion reads the
/// raster rather than a widget's declared size — a missing glyph keeps the
/// size. Rasterising is driven by the engine, so it runs outside the test's
/// fake async, where its futures would never complete.
Future<List<Uint8List>> _rastersOf(WidgetTester tester, List<Key> keys) async {
  final rasters = await tester.runAsync(() async {
    final captured = <Uint8List>[];
    for (final key in keys) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
      );
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      captured.add(data!.buffer.asUint8List());
    }
    return captured;
  });
  return rasters!;
}

/// Any decoded bitmap of the fixture's exact edge length — proving *our* bytes
/// reached the raster, not merely that some image widget exists.
final _fixtureRaster = find.byWidgetPredicate(
  (widget) => widget is RawImage && widget.image?.width == kGoldenArtEdge,
);

void main() {
  // These guards are untagged: they must run on a developer machine, because
  // they are the only local proof that a reference image would be meaningful.

  testWidgets('text renders with real glyph metrics, not the box font', (
    tester,
  ) async {
    final style = goldenTheme().textTheme.bodyMedium;

    await tester.pumpWidget(
      MaterialApp(
        theme: goldenTheme(),
        home: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('IIIIII', style: style),
              Text('WWWWWW', style: style),
            ],
          ),
        ),
      ),
    );

    // The `flutter test` default font gives every glyph a 1em advance, so these
    // two would measure identically without the loaded font.
    expect(
      tester.getSize(find.text('WWWWWW')).width,
      greaterThan(tester.getSize(find.text('IIIIII')).width),
    );
  });

  testWidgets('digits keep their column as a value changes', (tester) async {
    // Asserts the property a card's layout depends on, not the mechanism that
    // delivers it: this face gives equal-advance digits on its own, another may
    // need the tabular-figures feature asked for explicitly. Either way a
    // number that grows must not move what sits beside it, and a brand face
    // adopted without the feature would land here in red.
    final style = goldenTheme().textTheme.bodyMedium?.copyWith(
      fontFeatures: const [ui.FontFeature.tabularFigures()],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: goldenTheme(),
        home: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('111111', key: const Key('narrowDigits'), style: style),
              Text('999999', key: const Key('wideDigits'), style: style),
            ],
          ),
        ),
      ),
    );

    double widthOf(String key) => tester.getSize(find.byKey(Key(key))).width;

    expect(widthOf('narrowDigits'), widthOf('wideDigits'));
  });

  testWidgets('bundled icon glyphs draw their own shape, not the missing-glyph '
      'box', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: goldenTheme(),
        home: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                key: Key('motifA'),
                child: Icon(Icons.emoji_events_outlined, size: 48),
              ),
              RepaintBoundary(
                key: Key('motifB'),
                child: Icon(Icons.close, size: 48),
              ),
            ],
          ),
        ),
      ),
    );

    final rasters = await _rastersOf(tester, const [
      Key('motifA'),
      Key('motifB'),
    ]);

    // With no icon family registered both codepoints fall back to the same
    // blank box, so the two rasters come out byte-identical.
    expect(rasters.first, isNot(equals(rasters.last)));
  });

  testWidgets('seeded art reaches the rendered card', (tester) async {
    await pumpCardGolden(
      tester,
      card: _milestoneCard(),
      width: goldenFullWidth,
      cards: _steamLibrary(heroImage: goldenArtUrlA),
      art: const {goldenArtUrlA: goldenArtColorA},
    );

    // With the seam broken the image resolve fails, the frame builder returns
    // the placeholder, and no raster is mounted at all.
    expect(_fixtureRaster, findsOneWidget);
  });

  testWidgets('a card with no art renders no raster', (tester) async {
    await pumpCardGolden(
      tester,
      card: _milestoneCard(),
      width: goldenFullWidth,
      cards: _steamLibrary(),
    );

    // Also the framed degradation: with no cover the card is a drawn motif, so
    // there is nothing raster-backed in it at all.
    expect(_fixtureRaster, findsNothing);
    expect(find.byType(RawImage), findsNothing);
  });
}
