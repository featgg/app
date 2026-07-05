import 'package:cached_network_image/cached_network_image.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/collection_selection.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/presentation/collection_card_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Returns a fixed card per platform from the injected map; null for the rest.
final class _FakeCardsRepository implements CardsRepository {
  _FakeCardsRepository(this._cards);

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

/// A Steam card whose library holds [count] art-less entries (app ids 1..count),
/// so no real image decodes in tests.
GameCard _steamCard(int count, {bool withArt = false}) => GameCard(
  schemaVersion: 1,
  platform: Platform.steam,
  title: 'steam-card',
  subtitle: null,
  iconImage: null,
  heroImage: null,
  profileUrl: null,
  stats: const [],
  lastUpdated: DateTime.utc(2026, 6, 1),
  data: SteamCardData(
    libraryShowcase: [
      for (var i = 1; i <= count; i++)
        LibraryShowcaseEntry(
          appId: i,
          title: 'Game $i',
          hours: 100,
          heroImage: withArt ? 'https://cdn.example/$i.jpg' : null,
        ),
    ],
    recentGames: const [],
  ),
);

ProfileWidget _collectionWidget({
  required int count,
  ProfileWidgetSize size = ProfileWidgetSize.wide,
  String? titleKey = 'collectionTitleFavorites',
  List<String>? gameRefs,
}) => ProfileWidget(
  id: 'c-1',
  kind: ProfileWidgetKind.collection,
  platform: null,
  position: 0,
  isEnabled: true,
  size: size,
  collectionSelection: CollectionSelection(
    gameRefs: gameRefs ?? [for (var i = 1; i <= count; i++) '$i'],
    titleKey: titleKey,
  ),
);

Widget _harness({
  required ProfileWidget widget,
  required Map<Platform, GameCard?> cards,
  bool showEmptyPlaceholder = true,
}) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      cardsRepositoryProvider.overrideWithValue(_FakeCardsRepository(cards)),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: SingleChildScrollView(
          child: CollectionCardView(
            widget: widget,
            showEmptyPlaceholder: showEmptyPlaceholder,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('panel count', () {
    for (final n in [3, 4, 5]) {
      testWidgets('renders exactly $n panels for $n games', (tester) async {
        await tester.pumpWidget(
          _harness(
            widget: _collectionWidget(count: n),
            cards: {Platform.steam: _steamCard(n)},
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('collectionCard_c-1')), findsOneWidget);
        for (var i = 0; i < n; i++) {
          expect(
            find.byKey(Key('collectionPanel_c-1_$i')),
            findsOneWidget,
            reason: 'panel $i missing',
          );
        }
        expect(find.byKey(Key('collectionPanel_c-1_$n')), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    // Post-creation drift: a stored 3–5 game collection whose library rotated
    // down to 1–2 present games resolves to a degenerate panel count.
    testWidgets('one resolved game renders a single panel and no cut layer', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          // Three stored refs, only one still present in the library.
          widget: _collectionWidget(count: 3),
          cards: {Platform.steam: _steamCard(1)},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('collectionCard_c-1')), findsOneWidget);
      expect(find.byKey(const Key('collectionPanel_c-1_0')), findsOneWidget);
      expect(find.byKey(const Key('collectionPanel_c-1_1')), findsNothing);
      // A lone panel has no interior dividers, so the cut layer is omitted.
      expect(find.byKey(const Key('collectionCuts_c-1')), findsNothing);
      // The identity text still renders on the single-panel card.
      expect(find.byKey(const Key('collectionLabel_c-1')), findsOneWidget);
      expect(find.byKey(const Key('collectionMeta_c-1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('two resolved games render two panels and one cut layer', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          // Three stored refs, two still present in the library.
          widget: _collectionWidget(count: 3),
          cards: {Platform.steam: _steamCard(2)},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('collectionCard_c-1')), findsOneWidget);
      expect(find.byKey(const Key('collectionPanel_c-1_0')), findsOneWidget);
      expect(find.byKey(const Key('collectionPanel_c-1_1')), findsOneWidget);
      expect(find.byKey(const Key('collectionPanel_c-1_2')), findsNothing);
      // Two panels share one interior divider, so the cut layer is present.
      expect(find.byKey(const Key('collectionCuts_c-1')), findsOneWidget);
      expect(find.byKey(const Key('collectionLabel_c-1')), findsOneWidget);
      expect(find.byKey(const Key('collectionMeta_c-1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the cut painter is present for a multi-panel panorama', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        widget: _collectionWidget(count: 3),
        cards: {Platform.steam: _steamCard(3)},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('collectionCuts_c-1')), findsOneWidget);
  });

  testWidgets('art-absent panels render neutral surfaces, no image', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        widget: _collectionWidget(count: 3),
        cards: {Platform.steam: _steamCard(3)},
      ),
    );
    await tester.pumpAndSettle();

    // Every art tile is present, but with null urls none decodes an image.
    expect(find.byKey(const Key('collectionArt_c-1_0')), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('label + meta by size', () {
    testWidgets('large shows label + meta', (tester) async {
      await tester.pumpWidget(
        _harness(
          widget: _collectionWidget(count: 4, size: ProfileWidgetSize.large),
          cards: {Platform.steam: _steamCard(4)},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('collectionLabel_c-1')), findsOneWidget);
      expect(find.byKey(const Key('collectionMeta_c-1')), findsOneWidget);
    });

    testWidgets('wide shows label + meta', (tester) async {
      await tester.pumpWidget(
        _harness(
          widget: _collectionWidget(count: 3, size: ProfileWidgetSize.wide),
          cards: {Platform.steam: _steamCard(3)},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('collectionLabel_c-1')), findsOneWidget);
      expect(find.byKey(const Key('collectionMeta_c-1')), findsOneWidget);
    });

    testWidgets('small shows the label but omits the meta', (tester) async {
      await tester.pumpWidget(
        _harness(
          widget: _collectionWidget(count: 3, size: ProfileWidgetSize.small),
          cards: {Platform.steam: _steamCard(3)},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('collectionLabel_c-1')), findsOneWidget);
      expect(find.byKey(const Key('collectionMeta_c-1')), findsNothing);
    });

    testWidgets('an unresolved / absent title omits the label line', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          widget: _collectionWidget(count: 3, titleKey: null),
          cards: {Platform.steam: _steamCard(3)},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('collectionLabel_c-1')), findsNothing);
      // The panorama + meta still render (lenient, never drops the row).
      expect(find.byKey(const Key('collectionCard_c-1')), findsOneWidget);
      expect(find.byKey(const Key('collectionMeta_c-1')), findsOneWidget);
    });

    testWidgets('a stale title key omits the label line', (tester) async {
      await tester.pumpWidget(
        _harness(
          widget: _collectionWidget(count: 3, titleKey: 'collectionTitleGone'),
          cards: {Platform.steam: _steamCard(3)},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('collectionLabel_c-1')), findsNothing);
      expect(find.byKey(const Key('collectionCard_c-1')), findsOneWidget);
    });
  });

  group('zero-resolve degrade', () {
    testWidgets('owner sees the placeholder when nothing resolves', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          // Refs not in the library → zero panels.
          widget: _collectionWidget(count: 3, gameRefs: const ['999', '888']),
          cards: {Platform.steam: _steamCard(3)},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('collectionEmpty_c-1')), findsOneWidget);
      expect(find.byKey(const Key('collectionCard_c-1')), findsNothing);
    });

    testWidgets('a null card shows the owner placeholder', (tester) async {
      await tester.pumpWidget(
        _harness(
          widget: _collectionWidget(count: 3),
          cards: const {Platform.steam: null},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('collectionEmpty_c-1')), findsOneWidget);
    });

    testWidgets('showEmptyPlaceholder:false omits it entirely (visitor)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          widget: _collectionWidget(count: 3, gameRefs: const ['999']),
          cards: {Platform.steam: _steamCard(3)},
          showEmptyPlaceholder: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('collectionEmpty_c-1')), findsNothing);
      expect(find.byKey(const Key('collectionCard_c-1')), findsNothing);
    });
  });
}
