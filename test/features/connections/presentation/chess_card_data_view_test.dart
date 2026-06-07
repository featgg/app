import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/connections/presentation/chess_card_data_view.dart';
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
  home: Scaffold(body: child),
);

void main() {
  group('ChessCardDataView', () {
    testWidgets('renders primary mode and present mode rows', (tester) async {
      final data = ChessCardData(
        primaryMode: 'RAPID',
        ratings: {
          'rapid': const ChessModeRating(
            current: 1842,
            best: 1901,
            record: ChessRecord(win: 312, loss: 198, draw: 44),
          ),
          'blitz': const ChessModeRating(current: 1654, best: 1720),
        },
        puzzleRushScore: 37,
        tacticsBest: 2150,
        fide: 1900,
        titleFlags: const ChessTitleFlags(isTitled: true, title: 'FM'),
      );

      await tester.pumpWidget(_wrap(ChessCardDataView(data: data)));
      await tester.pump();

      expect(find.byKey(const Key('chessPrimaryModeLabel')), findsOneWidget);
      expect(find.byKey(const Key('chessRating_rapid')), findsOneWidget);
      expect(find.byKey(const Key('chessRating_blitz')), findsOneWidget);
      // bullet and daily not in ratings map — must not appear
      expect(find.byKey(const Key('chessRating_bullet')), findsNothing);
      expect(find.byKey(const Key('chessRating_daily')), findsNothing);
    });

    testWidgets('renders optional rows when fields are present', (
      tester,
    ) async {
      final data = ChessCardData(
        primaryMode: 'RAPID',
        ratings: const {},
        puzzleRushScore: 37,
        tacticsBest: 2150,
        fide: 1900,
        titleFlags: const ChessTitleFlags(isTitled: true, title: 'FM'),
      );

      await tester.pumpWidget(_wrap(ChessCardDataView(data: data)));
      await tester.pump();

      expect(find.byKey(const Key('chessTitleLabel')), findsOneWidget);
      expect(find.byKey(const Key('chessFideLabel')), findsOneWidget);
      expect(find.byKey(const Key('chessPuzzleRushLabel')), findsOneWidget);
      expect(find.byKey(const Key('chessTacticsLabel')), findsOneWidget);
    });

    testWidgets('renders primary mode record row when present', (tester) async {
      final data = ChessCardData(
        primaryMode: 'RAPID',
        ratings: {
          'rapid': const ChessModeRating(
            current: 1842,
            best: 1901,
            record: ChessRecord(win: 312, loss: 198, draw: 44),
          ),
        },
      );

      await tester.pumpWidget(_wrap(ChessCardDataView(data: data)));
      await tester.pump();

      expect(find.byKey(const Key('chessRecord')), findsOneWidget);
    });

    testWidgets('omits rows for absent optional fields', (tester) async {
      const data = ChessCardData(primaryMode: 'BLITZ', ratings: {});

      await tester.pumpWidget(_wrap(ChessCardDataView(data: data)));
      await tester.pump();

      expect(find.byKey(const Key('chessFideLabel')), findsNothing);
      expect(find.byKey(const Key('chessPuzzleRushLabel')), findsNothing);
      expect(find.byKey(const Key('chessTitleLabel')), findsNothing);
      expect(find.byKey(const Key('chessRecord')), findsNothing);
      expect(find.byKey(const Key('chessTacticsLabel')), findsNothing);
    });

    testWidgets('omits title row when isTitled is false', (tester) async {
      const data = ChessCardData(
        primaryMode: 'BLITZ',
        ratings: {},
        titleFlags: ChessTitleFlags(isTitled: false),
      );

      await tester.pumpWidget(_wrap(ChessCardDataView(data: data)));
      await tester.pump();

      expect(find.byKey(const Key('chessTitleLabel')), findsNothing);
    });
  });
}
