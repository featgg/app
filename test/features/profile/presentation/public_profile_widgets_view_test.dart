import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/composed_card.dart';
import 'package:featgg/src/features/profile/domain/data_menu_selection.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_repository.dart';
import 'package:featgg/src/features/profile/domain/showcase_selection.dart';
import 'package:featgg/src/features/profile/domain/template_catalog.dart';
import 'package:featgg/src/features/profile/presentation/public_profile_widgets_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Returns a fixed set of public widgets.
final class _FakeWidgetsRepository implements ProfileWidgetsRepository {
  _FakeWidgetsRepository(this.widgets);

  final List<ProfileWidget> widgets;

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchPublicWidgets(
    String userId,
  ) async => right(widgets);

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets() async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addPlatformWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addTemplateWidget({
    required String templateId,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setTemplateFill(
    String id,
    ProfileWidgetSize size,
    TemplateFill fill,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addComposedWidget({
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addShowcaseWidget({
    required Platform platform,
    required ShowcaseSelection selection,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setComposedFill(
    String id,
    ProfileWidgetSize size,
    ComposedFill fill,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> removeWidget(String id) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setSize(
    String id,
    ProfileWidgetSize size,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setShowcaseSize(
    String id,
    ProfileWidgetSize size,
    ShowcaseSelection selection,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setDataMenuSelection(
    String id,
    ProfileWidgetSize size,
    DataMenuSelection selection,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> reorder(List<String> orderedIds) async =>
      throw UnimplementedError();
}

/// Resolves the PUBLIC card per platform from [publicCards]; `fetchMyCard`
/// always returns null so a test can prove the visitor binds to the public
/// source (an owner-source binding would render nothing).
final class _SplitCardsRepository implements CardsRepository {
  _SplitCardsRepository(this.publicCards);

  final Map<Platform, GameCard?> publicCards;

  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) async =>
      right(null);

  @override
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  ) async => right(publicCards[platform]);
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

GameCard _card(
  Platform platform, {
  List<CardStat> stats = const [],
  DateTime? lastUpdated,
}) => GameCard(
  schemaVersion: 1,
  platform: platform,
  title: '${platform.name}-public-card',
  subtitle: null,
  iconImage: null,
  heroImage: null,
  profileUrl: null,
  stats: stats,
  lastUpdated: lastUpdated ?? DateTime.utc(2026, 6, 1),
  data: null,
);

ProfileWidget _widget({
  required String id,
  required Platform platform,
  required int position,
  bool isEnabled = true,
}) => ProfileWidget(
  id: id,
  kind: ProfileWidgetKind.platform,
  platform: platform,
  position: position,
  isEnabled: isEnabled,
  size: ProfileWidgetSize.small,
);

/// A public Steam card carrying one art-less library-showcase entry the showcase
/// view resolves against (art-less to avoid decoding a real image in tests).
GameCard _steamShowcaseCard() => GameCard(
  schemaVersion: 1,
  platform: Platform.steam,
  title: 'steam-public-card',
  subtitle: null,
  iconImage: null,
  heroImage: null,
  profileUrl: null,
  stats: const [],
  lastUpdated: DateTime.utc(2026, 6, 1),
  data: const SteamCardData(
    libraryShowcase: [
      LibraryShowcaseEntry(appId: 730, title: 'Counter-Strike 2', hours: 1234),
    ],
    recentGames: [],
  ),
);

Widget _harness({
  required List<ProfileWidget> widgets,
  Map<Platform, GameCard?> publicCards = const {},
}) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      profileWidgetsRepositoryProvider.overrideWithValue(
        _FakeWidgetsRepository(widgets),
      ),
      cardsRepositoryProvider.overrideWithValue(
        _SplitCardsRepository(publicCards),
      ),
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
          child: PublicProfileWidgetsView(
            userId: 'owner-2',
            // A keyed stand-in for the connections card so the public card's
            // title is assertable without importing the real GameCardView.
            cardBuilder: (card) =>
                SizedBox(height: 120, child: Text(card.title)),
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  testWidgets('a disabled widget is omitted; the enabled one renders', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        widgets: [
          _widget(id: 'on', platform: Platform.steam, position: 0),
          _widget(
            id: 'off',
            platform: Platform.chess,
            position: 1,
            isEnabled: false,
          ),
        ],
        publicCards: {
          Platform.steam: _card(Platform.steam),
          Platform.chess: _card(Platform.chess),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('publicWidgetTile_on')), findsOneWidget);
    expect(find.byKey(const Key('publicWidgetTile_off')), findsNothing);
  });

  testWidgets('widgets render in ascending position order', (tester) async {
    await tester.pumpWidget(
      _harness(
        widgets: [
          _widget(id: 'l', platform: Platform.gw2, position: 2),
          _widget(id: 's', platform: Platform.steam, position: 0),
          _widget(id: 'w', platform: Platform.chess, position: 1),
        ],
        publicCards: {
          Platform.steam: _card(Platform.steam),
          Platform.chess: _card(Platform.chess),
          Platform.gw2: _card(Platform.gw2),
        },
      ),
    );
    await tester.pumpAndSettle();

    final yS = tester
        .getTopLeft(find.byKey(const Key('publicWidgetTile_s')))
        .dy;
    final yW = tester
        .getTopLeft(find.byKey(const Key('publicWidgetTile_w')))
        .dy;
    final yL = tester
        .getTopLeft(find.byKey(const Key('publicWidgetTile_l')))
        .dy;
    expect(yS, lessThan(yW));
    expect(yW, lessThan(yL));
  });

  testWidgets('a platform widget resolves its card from the PUBLIC source', (
    tester,
  ) async {
    // fetchPublicCard returns a card; fetchMyCard returns null. The card is
    // visible only if the visitor scope binds to the public source.
    await tester.pumpWidget(
      _harness(
        widgets: [_widget(id: 'on', platform: Platform.steam, position: 0)],
        publicCards: {Platform.steam: _card(Platform.steam)},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('${Platform.steam.name}-public-card'), findsOneWidget);
  });

  testWidgets(
    'template and composed widgets resolve their cards from the PUBLIC source',
    (tester) async {
      // Both kinds bind a chess.rating row. The public chess card carries the
      // rating; fetchMyCard is null. The value renders only if each card view
      // received the public CardSource (an owner binding would soft-omit).
      await tester.pumpWidget(
        _harness(
          widgets: const [
            ProfileWidget(
              id: 'tmpl',
              kind: ProfileWidgetKind.template,
              platform: null,
              position: 0,
              isEnabled: true,
              size: ProfileWidgetSize.small,
              templateFill: TemplateFill('my_ranks', {
                'slot_1': 'chess.rating',
              }),
            ),
            ProfileWidget(
              id: 'comp',
              kind: ProfileWidgetKind.composed,
              platform: null,
              position: 1,
              isEnabled: true,
              size: ProfileWidgetSize.small,
              composedFill: ComposedFill(['chess.rating']),
            ),
          ],
          publicCards: {
            Platform.chess: _card(
              Platform.chess,
              stats: const [CardStat(key: 'rating', value: 1500)],
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('publicWidgetTile_tmpl')), findsOneWidget);
      expect(find.byKey(const Key('publicWidgetTile_comp')), findsOneWidget);
      // One row in each kind resolves the public chess rating.
      expect(find.text('1500'), findsNWidgets(2));
    },
  );

  testWidgets(
    'a stale WoW card is hidden from the visitor (viewer-aware freshness gate)',
    (tester) async {
      // A composed widget bound to a WoW stat, with a STALE public WoW card
      // (>30 days). The feed contract hides stale WoW from any non-owner viewer
      // entirely, so the value must not render on the visitor profile.
      await tester.pumpWidget(
        _harness(
          widgets: const [
            ProfileWidget(
              id: 'comp',
              kind: ProfileWidgetKind.composed,
              platform: null,
              position: 0,
              isEnabled: true,
              size: ProfileWidgetSize.small,
              composedFill: ComposedFill(['wow_retail.mythic_plus_rating']),
            ),
          ],
          publicCards: {
            Platform.wowRetail: _card(
              Platform.wowRetail,
              stats: const [CardStat(key: 'mythic_plus_rating', value: 2800)],
              lastUpdated: DateTime.now().subtract(const Duration(days: 40)),
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2800'), findsNothing);
    },
  );

  testWidgets('a fresh WoW card renders for the visitor', (tester) async {
    await tester.pumpWidget(
      _harness(
        widgets: const [
          ProfileWidget(
            id: 'comp',
            kind: ProfileWidgetKind.composed,
            platform: null,
            position: 0,
            isEnabled: true,
            size: ProfileWidgetSize.small,
            composedFill: ComposedFill(['wow_retail.mythic_plus_rating']),
          ),
        ],
        publicCards: {
          Platform.wowRetail: _card(
            Platform.wowRetail,
            stats: const [CardStat(key: 'mythic_plus_rating', value: 2800)],
            lastUpdated: DateTime.now(),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2800'), findsOneWidget);
  });

  testWidgets('an empty template widget is omitted for the visitor', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        widgets: const [
          ProfileWidget(
            id: 'empty-tmpl',
            kind: ProfileWidgetKind.template,
            platform: null,
            position: 0,
            isEnabled: true,
            size: ProfileWidgetSize.small,
            templateFill: TemplateFill('my_ranks', {}),
          ),
        ],
        publicCards: const {},
      ),
    );
    await tester.pumpAndSettle();

    // A visitor never sees an empty card — neither the card nor the owner-only
    // "fill a slot" placeholder renders.
    expect(find.byKey(const Key('templateCard_empty-tmpl')), findsNothing);
    expect(find.byKey(const Key('templateEmpty_empty-tmpl')), findsNothing);
  });

  testWidgets('no enabled widgets → empty state', (tester) async {
    await tester.pumpWidget(_harness(widgets: const []));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('publicProfileNoCards')), findsOneWidget);
    expect(find.byKey(const Key('publicProfileWidgetsView')), findsNothing);
  });

  testWidgets('all widgets disabled → empty state', (tester) async {
    await tester.pumpWidget(
      _harness(
        widgets: [
          _widget(
            id: 'off',
            platform: Platform.steam,
            position: 0,
            isEnabled: false,
          ),
        ],
        publicCards: {Platform.steam: _card(Platform.steam)},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('publicProfileNoCards')), findsOneWidget);
  });

  testWidgets(
    'a showcase widget renders via ShowcaseCardView using the public source',
    (tester) async {
      // fetchPublicCard returns the Steam card; fetchMyCard is null. The
      // showcase resolves only if the visitor tile bound the public source.
      await tester.pumpWidget(
        _harness(
          widgets: const [
            ProfileWidget(
              id: 'sc',
              kind: ProfileWidgetKind.showcase,
              platform: Platform.steam,
              position: 0,
              isEnabled: true,
              size: ProfileWidgetSize.small,
              showcaseSelection: ShowcaseSelection(gameRef: '730'),
            ),
          ],
          publicCards: {Platform.steam: _steamShowcaseCard()},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('publicWidgetTile_sc')), findsOneWidget);
      expect(find.byKey(const Key('showcaseCard_sc')), findsOneWidget);
    },
  );

  testWidgets('read-only: no options menu and no add affordance', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        widgets: [_widget(id: 'on', platform: Platform.steam, position: 0)],
        publicCards: {Platform.steam: _card(Platform.steam)},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profileWidgetMenu_on')), findsNothing);
    expect(find.byKey(const Key('profileWidgetAddButton')), findsNothing);
    expect(find.bySubtype<PopupMenuButton>(), findsNothing);
  });
}
