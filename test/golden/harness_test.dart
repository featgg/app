import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/profile_archetype.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/showcase_selection.dart';
import 'package:featgg/src/features/profile/presentation/personalization_archetype_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

/// A Milestone card bound to a Steam game. Milestone is the whole art path in
/// one card: no cover keeps the procedural capsule and drops the legibility
/// scrim, a resolved cover replaces both.
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

    expect(_fixtureRaster, findsNothing);
    expect(find.byType(RawImage), findsNothing);
  });
}
