import 'package:cached_network_image/cached_network_image.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/core/theme/personalization_tokens.dart';
import 'package:featgg/src/features/profile/domain/profile_archetype.dart';
import 'package:featgg/src/features/profile/presentation/personalization_archetype_cards.dart';
import 'package:featgg/src/features/profile/presentation/personalization_card_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _refreshKey = Key('personalizationStaleRefresh');

Widget _harness(Widget card) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('en')],
  home: Scaffold(
    body: PersonalizationTheme(
      palette: PersonalizationPalette.crimson,
      child: SizedBox(width: 320, child: card),
    ),
  ),
);

double _aspect(WidgetTester tester) => tester
    .widget<AspectRatio>(
      find.descendant(
        of: find.byType(PersonalizationStaleCard),
        matching: find.byType(AspectRatio),
      ),
    )
    .aspectRatio;

late AppLocalizations _en;

void main() {
  setUpAll(() async {
    _en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('renders framed with no art', (tester) async {
    await tester.pumpWidget(
      _harness(
        const PersonalizationStaleCard(
          archetype: ProfileArchetype.platform,
          size: ProfileCardSize.full,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PersonalizationCardGround), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byType(RawImage), findsNothing);
  });

  testWidgets('says the data is out of date and how to fix it', (tester) async {
    await tester.pumpWidget(
      _harness(
        const PersonalizationStaleCard(
          archetype: ProfileArchetype.platform,
          size: ProfileCardSize.full,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(_en.personalizationCardStale), findsOneWidget);
    expect(find.text(_en.personalizationCardStaleRefresh), findsOneWidget);
  });

  testWidgets('a tap runs the refresh action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _harness(
        PersonalizationStaleCard(
          archetype: ProfileArchetype.platform,
          size: ProfileCardSize.full,
          onRefresh: () => taps++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_refreshKey));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('is inert with no action', (tester) async {
    await tester.pumpWidget(
      _harness(
        const PersonalizationStaleCard(
          archetype: ProfileArchetype.platform,
          size: ProfileCardSize.full,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(_refreshKey), findsNothing);
  });

  testWidgets("keeps the archetype's own aspect", (tester) async {
    // A withheld card must not change the geometry of the slot it sits in, so
    // the two chassis shapes are pinned separately.
    await tester.pumpWidget(
      _harness(
        const PersonalizationStaleCard(
          archetype: ProfileArchetype.art,
          size: ProfileCardSize.full,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_aspect(tester), PersonalizationLayout.cardArtFullAspect);

    await tester.pumpWidget(
      _harness(
        const PersonalizationStaleCard(
          archetype: ProfileArchetype.platform,
          size: ProfileCardSize.full,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_aspect(tester), PersonalizationLayout.cardFullAspect);
  });

  testWidgets('a full-only archetype in a half slot renders full', (
    tester,
  ) async {
    // Sized through the same clamp the composed render applies to a real card,
    // so a withheld card and the card it replaces occupy the slot identically.
    const archetype = ProfileArchetype.collection;
    await tester.pumpWidget(
      _harness(
        PersonalizationStaleCard(
          archetype: archetype,
          size: renderedCardSize(archetype, ProfileCardSize.half),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_aspect(tester), PersonalizationLayout.cardFullAspect);
    expect(_aspect(tester), isNot(PersonalizationLayout.cardHalfAspect));
  });
}
