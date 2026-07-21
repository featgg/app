import 'package:featgg/src/core/core.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_repository.dart';
import 'package:featgg/src/features/profile/presentation/rank_main_add_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Records the rank/main add calls; the read the controller re-fetches after a
/// successful add returns `[]`. Every other method is out of scope.
final class _RecordingWidgetsRepository implements ProfileWidgetsRepository {
  Platform? lastRankPlatform;
  int? lastRankPosition;
  ProfileWidgetSize? lastRankSize;
  Platform? lastMainPlatform;
  int? lastMainPosition;
  ProfileWidgetSize? lastMainSize;

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets() async =>
      right(const []);

  @override
  Future<Either<Failure, ProfileWidget>> addRankWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async {
    lastRankPlatform = platform;
    lastRankPosition = position;
    lastRankSize = size;
    return right(
      ProfileWidget(
        id: 'new',
        kind: ProfileWidgetKind.rank,
        platform: platform,
        position: position,
        isEnabled: true,
        size: size,
      ),
    );
  }

  @override
  Future<Either<Failure, ProfileWidget>> addMainWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async {
    lastMainPlatform = platform;
    lastMainPosition = position;
    lastMainSize = size;
    return right(
      ProfileWidget(
        id: 'new',
        kind: ProfileWidgetKind.main,
        platform: platform,
        position: position,
        isEnabled: true,
        size: size,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Serves a fixed card per platform (null for the rest).
final class _MapCardsRepository implements CardsRepository {
  _MapCardsRepository(this._cards);

  final Map<Platform, GameCard?> _cards;

  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) async =>
      right(_cards[platform]);

  @override
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  ) async => right(null);
}

GameCard _card(Platform platform, CardData data) => GameCard(
  schemaVersion: 1,
  platform: platform,
  title: '${platform.name}-card',
  subtitle: null,
  iconImage: null,
  heroImage: null,
  profileUrl: null,
  stats: const [],
  lastUpdated: DateTime.utc(2026, 6, 1),
  data: data,
);

GameCard _chessCard() => _card(
  Platform.chess,
  const ChessCardData(
    primaryMode: 'RAPID',
    ratings: {'rapid': ChessModeRating(current: 1500, best: 1600)},
  ),
);

ProfileWidget _platformWidget({required int position}) => ProfileWidget(
  id: 'plat-$position',
  kind: ProfileWidgetKind.platform,
  platform: Platform.steam,
  position: position,
  isEnabled: true,
  size: ProfileWidgetSize.small,
);

ProfileWidget _rankWidget(Platform platform) => ProfileWidget(
  id: 'rank-${platform.name}',
  kind: ProfileWidgetKind.rank,
  platform: platform,
  position: 0,
  isEnabled: true,
  size: ProfileWidgetSize.small,
);

Widget _harness({
  required Map<Platform, GameCard?> cards,
  required _RecordingWidgetsRepository widgetsRepo,
  required List<ProfileWidget> existing,
}) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      cardsRepositoryProvider.overrideWithValue(_MapCardsRepository(cards)),
      profileWidgetsRepositoryProvider.overrideWithValue(widgetsRepo),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('openSheet'),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (_) => RankMainAddSection(existing: existing),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('openSheet')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'offers Rank and Main for a connected platform whose card carries '
    'the data',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          cards: {Platform.chess: _chessCard()},
          widgetsRepo: _RecordingWidgetsRepository(),
          existing: const [],
        ),
      );
      await tester.pumpAndSettle();
      await _open(tester);

      expect(find.byKey(const Key('rankAddRow_chess')), findsOneWidget);
      expect(find.byKey(const Key('mainAddRow_chess')), findsOneWidget);
    },
  );

  testWidgets('hides a connected platform whose payload lacks the data', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        // League unranked with no mastery: neither resolver finds data.
        cards: {
          Platform.leagueOfLegends: _card(
            Platform.leagueOfLegends,
            const LeagueOfLegendsCardData(rank: null, topMastery: []),
          ),
        },
        widgetsRepo: _RecordingWidgetsRepository(),
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);

    expect(find.byKey(const Key('rankAddRow_league_of_legends')), findsNothing);
    expect(find.byKey(const Key('mainAddRow_league_of_legends')), findsNothing);
  });

  testWidgets('hides an unsupported platform even when it has a card', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        cards: {
          Platform.minecraftHypixel: _card(
            Platform.minecraftHypixel,
            const MinecraftCardData(rank: 'DEFAULT', level: 10, karma: 0),
          ),
        },
        widgetsRepo: _RecordingWidgetsRepository(),
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);

    expect(find.byKey(const Key('rankAddRow_minecraftHypixel')), findsNothing);
    expect(find.byKey(const Key('mainAddRow_minecraftHypixel')), findsNothing);
  });

  testWidgets('hides an already-placed (kind, platform) but still offers the '
      'other kind', (tester) async {
    await tester.pumpWidget(
      _harness(
        cards: {Platform.chess: _chessCard()},
        widgetsRepo: _RecordingWidgetsRepository(),
        existing: [_rankWidget(Platform.chess)],
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);

    // The Rank for chess is already placed → not offered; Main still is.
    expect(find.byKey(const Key('rankAddRow_chess')), findsNothing);
    expect(find.byKey(const Key('mainAddRow_chess')), findsOneWidget);
  });

  testWidgets('tapping the Rank row adds a rank widget with the platform and '
      'max+1 position, then closes', (tester) async {
    final widgetsRepo = _RecordingWidgetsRepository();
    await tester.pumpWidget(
      _harness(
        cards: {Platform.chess: _chessCard()},
        widgetsRepo: widgetsRepo,
        // A non-rank widget at position 2 proves the insert position is max+1 = 3.
        existing: [_platformWidget(position: 2)],
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);

    await tester.tap(find.byKey(const Key('rankAddRow_chess')));
    await tester.pumpAndSettle();

    expect(widgetsRepo.lastRankPlatform, Platform.chess);
    expect(widgetsRepo.lastRankPosition, 3);
    expect(widgetsRepo.lastRankSize, ProfileWidgetSize.small);
    expect(widgetsRepo.lastMainPlatform, isNull);
    // The sheet closed on tap.
    expect(find.byKey(const Key('rankAddRow_chess')), findsNothing);
  });

  testWidgets('tapping the Main row adds a main widget with the platform and '
      'max+1 position', (tester) async {
    final widgetsRepo = _RecordingWidgetsRepository();
    await tester.pumpWidget(
      _harness(
        cards: {Platform.chess: _chessCard()},
        widgetsRepo: widgetsRepo,
        existing: [_platformWidget(position: 2)],
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);

    await tester.tap(find.byKey(const Key('mainAddRow_chess')));
    await tester.pumpAndSettle();

    expect(widgetsRepo.lastMainPlatform, Platform.chess);
    expect(widgetsRepo.lastMainPosition, 3);
    expect(widgetsRepo.lastMainSize, ProfileWidgetSize.small);
    expect(widgetsRepo.lastRankPlatform, isNull);
  });

  testWidgets('with zero qualifying candidates the section collapses to '
      'nothing', (tester) async {
    await tester.pumpWidget(
      _harness(
        cards: const {},
        widgetsRepo: _RecordingWidgetsRepository(),
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);

    // No section container and no rows: the widget rendered SizedBox.shrink.
    expect(find.byKey(const Key('rankMainAddSection')), findsNothing);
    expect(find.byType(RankMainAddSection), findsOneWidget);
  });
}
