import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/core/theme/personalization_tokens.dart';
import 'package:featgg/src/features/profile/presentation/personalization_card_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mounts the footer at a fixed [width] so the narrow half-card geometry that
/// overflowed on device is reproduced exactly.
Widget _wrap({
  required double width,
  required List<PersonalizationStat> stats,
}) => MaterialApp(
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
          child: PersonalizationStatFooter(
            stats: stats,
            palette: PersonalizationPalette.crimson,
          ),
        ),
      ),
    ),
  ),
);

/// Mounts a whole [CardShell] at a fixed [width] so the title bar's title +
/// platform-tag Row is exercised at the narrow half-card geometry.
Widget _wrapCard({required double width, required String platformTag}) =>
    MaterialApp(
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
              child: CardShell(
                title: 'Rank',
                platformTag: platformTag,
                content: const SizedBox(),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('stat footer does not overflow on a narrow half card', (
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

    await tester.pumpWidget(_wrap(width: 150, stats: stats));
    await tester.pump();

    // Each entry is width-bounded, so the labels ellipsize instead of forcing
    // the footer Row past its half-card width.
    expect(tester.takeException(), isNull);
    expect(find.text('1.2K'), findsOneWidget);
    expect(find.text('4.6K'), findsOneWidget);
  });

  testWidgets('title bar does not overflow with a long platform tag on a narrow '
      'half card', (tester) async {
    tester.view.physicalSize = const Size(340, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // The two device tags that overflowed the unbounded title-bar tag on the
    // reporting geometry. Each must ellipsize within its half, not blow the Row.
    for (final tag in const [
      'World of Warcraft (Retail)',
      'RetroAchievements',
    ]) {
      await tester.pumpWidget(_wrapCard(width: 150, platformTag: tag));
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: 'tag "$tag" must be bounded, not overflow the title bar',
      );
    }
  });

  testWidgets('stat footer renders every stat at full-card width', (
    tester,
  ) async {
    const stats = [
      PersonalizationStat(value: '12', label: 'Wins'),
      PersonalizationStat(value: '34', label: 'Losses'),
    ];

    await tester.pumpWidget(_wrap(width: 560, stats: stats));
    await tester.pump();

    // Bounding each entry must not degrade a card that already fits: short stats
    // at full width still render both values with no exception.
    expect(tester.takeException(), isNull);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('34'), findsOneWidget);
  });
}
