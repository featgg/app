import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/connections/presentation/gw2_card_data_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

const _fullAccount = Gw2Account(
  accountAgeHours: 43800,
  veterancyYears: 5,
  totalAp: 18500,
  fractalLevel: 100,
  wvwRank: 312,
  homeWorld: 'Tarnished Coast',
);

const _fullData = Gw2CardData(
  mainProfession: 'GUARDIAN',
  account: _fullAccount,
  topCharacters: [
    Gw2Character(
      name: 'TestChar',
      race: 'Human',
      profession: 'GUARDIAN',
      level: 80,
      deaths: 42,
      hoursPlayed: 1200,
      isMain: true,
    ),
  ],
);

void main() {
  group('Gw2CardDataView', () {
    testWidgets('renders present rows', (tester) async {
      await tester.pumpWidget(_wrap(const Gw2CardDataView(data: _fullData)));
      await tester.pump();

      expect(find.byKey(const Key('gw2MainProfession')), findsOneWidget);
      expect(find.byKey(const Key('gw2AccountAge')), findsOneWidget);
      expect(find.byKey(const Key('gw2Veterancy')), findsOneWidget);
      expect(find.byKey(const Key('gw2TotalAp')), findsOneWidget);
      expect(find.byKey(const Key('gw2FractalLevel')), findsOneWidget);
      expect(find.byKey(const Key('gw2WvwRank')), findsOneWidget);
      expect(find.byKey(const Key('gw2HomeWorld')), findsOneWidget);
      expect(find.byKey(const Key('gw2CharactersHeader')), findsOneWidget);
      expect(find.byKey(const Key('gw2Character_0')), findsOneWidget);
    });

    testWidgets('omits scope-gated rows when null and empty topCharacters', (
      tester,
    ) async {
      const sparseData = Gw2CardData(
        mainProfession: 'WARRIOR',
        account: Gw2Account(
          accountAgeHours: 100,
          veterancyYears: 1,
          // totalAp, fractalLevel, wvwRank, homeWorld all null
        ),
        topCharacters: [],
      );

      await tester.pumpWidget(_wrap(const Gw2CardDataView(data: sparseData)));
      await tester.pump();

      // Required rows still present
      expect(find.byKey(const Key('gw2AccountAge')), findsOneWidget);
      expect(find.byKey(const Key('gw2Veterancy')), findsOneWidget);

      // Scope-gated rows absent
      expect(find.byKey(const Key('gw2TotalAp')), findsNothing);
      expect(find.byKey(const Key('gw2FractalLevel')), findsNothing);
      expect(find.byKey(const Key('gw2WvwRank')), findsNothing);
      expect(find.byKey(const Key('gw2HomeWorld')), findsNothing);

      // Characters section absent
      expect(find.byKey(const Key('gw2CharactersHeader')), findsNothing);
      expect(find.byKey(const Key('gw2Character_0')), findsNothing);
    });

    testWidgets('omits main profession row when null', (tester) async {
      const noProf = Gw2CardData(
        // mainProfession omitted (null)
        account: Gw2Account(accountAgeHours: 200, veterancyYears: 2),
        topCharacters: [],
      );

      await tester.pumpWidget(_wrap(const Gw2CardDataView(data: noProf)));
      await tester.pump();

      expect(find.byKey(const Key('gw2MainProfession')), findsNothing);
      expect(find.byKey(const Key('gw2AccountAge')), findsOneWidget);
    });
  });
}
