import 'package:cached_network_image/cached_network_image.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/core/theme/personalization_tokens.dart';
import 'package:featgg/src/features/profile/domain/profile_archetype.dart';
import 'package:featgg/src/features/profile/presentation/personalization_card_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mounts [child] under the palette every personalization widget reads.
Widget _wrap({required double width, required Widget child}) => MaterialApp(
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
        width: width,
        child: PersonalizationTheme(
          palette: PersonalizationPalette.crimson,
          child: child,
        ),
      ),
    ),
  ),
);

/// Mounts the datum alone at a fixed [width] so the narrow half-card geometry
/// that overflowed on device is reproduced exactly.
Widget _wrapDatum({
  required double width,
  required List<PersonalizationStat> stats,
}) => _wrap(
  width: width,
  child: PersonalizationDatum(
    format: ProfileCardFormat.framed,
    // The half-card height [width] implies, so the datum sizes its type the
    // same way it does inside a real card.
    cardHeight: width / PersonalizationLayout.cardHalfAspect,
    stats: stats,
  ),
);

/// Mounts a whole shell for [archetype] at a fixed [width].
Widget _wrapCard({
  required double width,
  required ProfileArchetype archetype,
  String? art,
  String? subject,
  String? detail,
  List<PersonalizationStat> stats = const [],
  ProfileCardSize size = ProfileCardSize.full,
}) => _wrap(
  width: width,
  child: PersonalizationCardShell(
    archetype: archetype,
    size: size,
    art: art,
    subject: subject,
    detail: detail,
    stats: stats,
  ),
);

const _artUrl = 'https://cdn.test/cover.jpg';

/// The art layer loading exactly [url] — asserted independent of load outcome,
/// which a widget test can never reach.
Finder _artFor(String url) =>
    find.byWidgetPredicate((w) => w is CachedNetworkImage && w.imageUrl == url);

/// Every [Text] the card draws, with the shell's own bounds — the "nothing at
/// the top" rule is a geometric claim, so it is measured, not inferred.
void _expectNothingInTheTopHalf(WidgetTester tester) {
  final cardTop = tester.getTopLeft(find.byType(PersonalizationCardShell)).dy;
  final cardHeight = tester
      .getSize(find.byType(PersonalizationCardShell))
      .height;
  final midpoint = cardTop + cardHeight / 2;
  final texts = find.descendant(
    of: find.byType(PersonalizationCardShell),
    matching: find.byType(Text),
  );
  expect(texts, findsWidgets, reason: 'the card must draw its datum');
  for (var i = 0; i < tester.widgetList(texts).length; i++) {
    final top = tester.getTopLeft(texts.at(i)).dy;
    expect(
      top,
      greaterThanOrEqualTo(midpoint),
      reason: 'no text may sit in the card\'s top half',
    );
  }
}

void main() {
  testWidgets('a bleed archetype with art renders the art and no ground fill', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapCard(
        width: 300,
        archetype: ProfileArchetype.milestone,
        art: _artUrl,
        subject: 'Counter-Strike',
      ),
    );
    await tester.pump();

    expect(_artFor(_artUrl), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is PersonalizationDatum && w.format == ProfileCardFormat.bleed,
      ),
      findsOneWidget,
    );
    // A bleed card never builds the framed chassis: the ground can only
    // appear as the art layer's own placeholder, never as the card's fill.
    expect(
      tester.widgetList(find.byType(PersonalizationCardGround)),
      hasLength(
        tester
            .widgetList(
              find.descendant(
                of: _artFor(_artUrl),
                matching: find.byType(PersonalizationCardGround),
              ),
            )
            .length,
      ),
    );
    // The bleed datum sits directly over the art — it has no band.
    expect(
      find.descendant(
        of: find.byType(PersonalizationDatum),
        matching: find.byType(Container),
      ),
      findsNothing,
    );
  });

  testWidgets('a bleed datum carries the on-art legibility shadow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapCard(
        width: 300,
        archetype: ProfileArchetype.milestone,
        art: _artUrl,
        subject: 'Counter-Strike',
      ),
    );
    await tester.pump();

    final style = tester.widget<Text>(find.text('Counter-Strike')).style!;
    expect(style.shadows, PersonalizationArtText.shadows);
    expect(style.color, PersonalizationArtColors.onArt);
  });

  testWidgets('the same archetype with no art renders its ground and a '
      'datum band closed by a single bottom line', (tester) async {
    await tester.pumpWidget(
      _wrapCard(
        width: 300,
        archetype: ProfileArchetype.milestone,
        subject: 'Counter-Strike',
      ),
    );
    await tester.pump();

    expect(find.byType(PersonalizationCardGround), findsOneWidget);

    final decoration =
        tester
                .widget<Container>(
                  find.descendant(
                    of: find.byType(PersonalizationDatum),
                    matching: find.byType(Container),
                  ),
                )
                .decoration
            as BoxDecoration;
    final border = decoration.border! as Border;
    expect(border.bottom.color, PersonalizationPalette.crimson.line);
    // The bottom line is the only border on the card: no side and no top edge.
    expect(border.top, BorderSide.none);
    expect(border.left, BorderSide.none);
    expect(border.right, BorderSide.none);
  });

  testWidgets('a framed archetype handed art still renders framed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapCard(
        width: 300,
        archetype: ProfileArchetype.rank,
        art: _artUrl,
        subject: 'GOLD IV',
      ),
    );
    await tester.pump();

    // The registry, not the caller, owns the format.
    expect(find.byType(PersonalizationCardGround), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is PersonalizationDatum && w.format == ProfileCardFormat.framed,
      ),
      findsOneWidget,
    );
  });

  testWidgets('nothing sits at the top of a bleed card', (tester) async {
    await tester.pumpWidget(
      _wrapCard(
        width: 300,
        archetype: ProfileArchetype.milestone,
        art: _artUrl,
        subject: 'Counter-Strike',
        detail: 'Steam',
        stats: const [PersonalizationStat(value: '1.2K', label: 'Hours')],
      ),
    );
    await tester.pump();

    _expectNothingInTheTopHalf(tester);
  });

  testWidgets('nothing sits at the top of a framed card', (tester) async {
    await tester.pumpWidget(
      _wrapCard(
        width: 300,
        archetype: ProfileArchetype.rank,
        subject: 'GOLD IV',
        detail: 'SOLO QUEUE',
        stats: const [PersonalizationStat(value: '42 LP', label: 'Rank LP')],
      ),
    );
    await tester.pump();

    _expectNothingInTheTopHalf(tester);
  });

  testWidgets('the datum does not overflow on a narrow half card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(340, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const stats = [
      PersonalizationStat(
        value: '1.2K',
        label: 'Total matches played this season',
      ),
      PersonalizationStat(
        value: '4.6K',
        label: 'Hours across every tracked mode',
      ),
    ];

    await tester.pumpWidget(_wrapDatum(width: 150, stats: stats));
    await tester.pump();

    // Each entry is width-bounded, so the labels ellipsize instead of forcing
    // the datum Row past its half-card width.
    expect(tester.takeException(), isNull);
    expect(find.text('1.2K'), findsOneWidget);
    expect(find.text('4.6K'), findsOneWidget);
  });

  testWidgets('the datum renders every stat at full-card width', (
    tester,
  ) async {
    const stats = [
      PersonalizationStat(value: '12', label: 'Wins'),
      PersonalizationStat(value: '34', label: 'Losses'),
    ];

    await tester.pumpWidget(_wrapDatum(width: 560, stats: stats));
    await tester.pump();

    // Bounding each entry must not degrade a card that already fits: short stats
    // at full width still render both values with no exception.
    expect(tester.takeException(), isNull);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('34'), findsOneWidget);
  });
}
