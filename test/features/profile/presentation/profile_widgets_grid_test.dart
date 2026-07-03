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
import 'package:featgg/src/features/profile/presentation/profile_widgets_controller.dart';
import 'package:featgg/src/features/profile/presentation/profile_widgets_grid.dart';
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

/// Returns a Left so the card read lands in an error state — exercises the
/// AsyncValueWidget error/retry view (distinct from a missing card → null).
final class _ErrorCardsRepository implements CardsRepository {
  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) async =>
      left(const NetworkFailure());

  @override
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  ) async => left(const NetworkFailure());
}

/// Stub never exercised by the grid render path (the menu is not opened in
/// these tests); satisfies the controller's repository dependency.
final class _StubWidgetsRepository implements ProfileWidgetsRepository {
  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets() async =>
      right(const []);

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchPublicWidgets(
    String userId,
  ) async => right(const []);

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
  Future<Either<Failure, Unit>> setDataMenuSelection(
    String id,
    ProfileWidgetSize size,
    DataMenuSelection selection,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> reorder(List<String> orderedIds) async =>
      throw UnimplementedError();
}

/// Records the size passed to [setSize] so the showcase resize flow is provable
/// at the repository boundary the controller drives.
final class _RecordingWidgetsRepository implements ProfileWidgetsRepository {
  ProfileWidgetSize? lastSetSize;

  @override
  Future<Either<Failure, Unit>> setSize(
    String id,
    ProfileWidgetSize size,
  ) async {
    lastSetSize = size;
    return right(unit);
  }

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets() async =>
      right(const []);

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchPublicWidgets(
    String userId,
  ) async => right(const []);

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
  Future<Either<Failure, Unit>> setDataMenuSelection(
    String id,
    ProfileWidgetSize size,
    DataMenuSelection selection,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> reorder(List<String> orderedIds) async =>
      throw UnimplementedError();
}

GameCard _card(Platform platform, {List<CardStat> stats = const []}) =>
    GameCard(
      schemaVersion: 1,
      platform: platform,
      title: '${platform.name}-card',
      subtitle: null,
      iconImage: null,
      heroImage: null,
      profileUrl: null,
      stats: stats,
      lastUpdated: DateTime.utc(2026, 6, 1),
      data: null,
    );

ProfileWidget _templateWidget({
  required String id,
  required int position,
  required TemplateFill fill,
}) => ProfileWidget(
  id: id,
  kind: ProfileWidgetKind.template,
  platform: null,
  position: position,
  isEnabled: true,
  size: ProfileWidgetSize.small,
  templateFill: fill,
);

ProfileWidget _showcaseWidget({required String id, required int position}) =>
    ProfileWidget(
      id: id,
      kind: ProfileWidgetKind.showcase,
      platform: Platform.steam,
      position: position,
      isEnabled: true,
      size: ProfileWidgetSize.small,
      showcaseSelection: const ShowcaseSelection(gameRef: '730'),
    );

/// A Steam card carrying one library-showcase entry (art-less to avoid decoding
/// a real image in tests) that the showcase view resolves against.
GameCard _steamShowcaseCard() => GameCard(
  schemaVersion: 1,
  platform: Platform.steam,
  title: 'steam-card',
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

ProfileWidget _widget({
  required String id,
  required Platform platform,
  required int position,
  required ProfileWidgetSize size,
  bool isEnabled = true,
}) => ProfileWidget(
  id: id,
  kind: ProfileWidgetKind.platform,
  platform: platform,
  position: position,
  isEnabled: isEnabled,
  size: size,
);

Widget _harness({
  required List<ProfileWidget> widgets,
  required Map<Platform, GameCard?> cards,
  ProfileWidgetsRepository? widgetsRepo,
}) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      cardsRepositoryProvider.overrideWithValue(_FakeCardsRepository(cards)),
      profileWidgetsRepositoryProvider.overrideWithValue(
        widgetsRepo ?? _StubWidgetsRepository(),
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
        // Observe the mutation controller so the autoDispose notifier stays
        // alive across a menu-driven mutation, mirroring the profile screen's
        // own listener (a grid tile alone would let it dispose mid-write).
        body: Consumer(
          builder: (context, ref, child) {
            ref.listen(profileWidgetsControllerProvider, (_, _) {});
            return child!;
          },
          child: SingleChildScrollView(
            child: ProfileWidgetsGrid(
              widgets: widgets,
              // A full-height card stand-in (the real connections card is tall):
              // gives the tile enough content height for the options-menu
              // overlay to sit within its bounds, keeping the title assertable.
              cardBuilder: (card) =>
                  SizedBox(height: 200, child: Text(card.title)),
            ),
          ),
        ),
      ),
    ),
  );
}

/// A deliberately tall, wide-content stand-in for the real connections
/// `GameCardView` (which must not be imported here): a column of tall boxes plus
/// a wide row of fixed-width boxes — the shape that overflowed inside the old
/// fixed-aspect staggered cells.
class _TallWideCard extends StatelessWidget {
  const _TallWideCard({required this.cardKey});

  final Key cardKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: cardKey,
      children: [
        for (var i = 0; i < 4; i++) const SizedBox(height: 200, width: 320),
        Row(children: [for (var i = 0; i < 6; i++) const SizedBox(width: 120)]),
      ],
    );
  }
}

void main() {
  testWidgets('renders a tall, rich card at phone width with no overflow', (
    tester,
  ) async {
    // Constrain to a phone width so the layout resolves at the size the old
    // staggered grid overflowed at; a RenderFlex overflow surfaces as a thrown
    // FlutterError in a test, so a null takeException proves none fired.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      retry: (count, error) => null,
      overrides: [
        cardsRepositoryProvider.overrideWithValue(
          _FakeCardsRepository({Platform.steam: _card(Platform.steam)}),
        ),
        profileWidgetsRepositoryProvider.overrideWithValue(
          _StubWidgetsRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
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
              child: ProfileWidgetsGrid(
                widgets: [
                  _widget(
                    id: 'tall',
                    platform: Platform.steam,
                    position: 0,
                    size: ProfileWidgetSize.small,
                  ),
                ],
                cardBuilder: (card) =>
                    const _TallWideCard(cardKey: Key('tallWideCard')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No RenderFlex overflow / FlutterError was thrown during layout — the
    // guard the old fixed-aspect StaggeredGridTile.count layout failed.
    expect(tester.takeException(), isNull);
    // The tall card actually rendered (not hidden / collapsed).
    expect(find.byKey(const Key('tallWideCard')), findsOneWidget);
  });

  testWidgets('renders one full-width tile per visible widget in position '
      'order', (tester) async {
    final widgets = [
      _widget(
        id: 'l',
        platform: Platform.gw2,
        position: 2,
        size: ProfileWidgetSize.large,
      ),
      _widget(
        id: 's',
        platform: Platform.steam,
        position: 0,
        size: ProfileWidgetSize.small,
      ),
      _widget(
        id: 'w',
        platform: Platform.chess,
        position: 1,
        size: ProfileWidgetSize.wide,
      ),
    ];
    await tester.pumpWidget(
      _harness(
        widgets: widgets,
        cards: {
          Platform.steam: _card(Platform.steam),
          Platform.chess: _card(Platform.chess),
          Platform.gw2: _card(Platform.gw2),
        },
      ),
    );
    await tester.pumpAndSettle();

    // Every widget renders regardless of its (now visually inert) size token,
    // laid out as a plain column — the staggered grid is gone.
    expect(find.byKey(const Key('profileWidgetTile_s')), findsOneWidget);
    expect(find.byKey(const Key('profileWidgetTile_w')), findsOneWidget);
    expect(find.byKey(const Key('profileWidgetTile_l')), findsOneWidget);

    // Tiles render in ascending position order, top to bottom.
    final yS = tester
        .getTopLeft(find.byKey(const Key('profileWidgetTile_s')))
        .dy;
    final yW = tester
        .getTopLeft(find.byKey(const Key('profileWidgetTile_w')))
        .dy;
    final yL = tester
        .getTopLeft(find.byKey(const Key('profileWidgetTile_l')))
        .dy;
    expect(yS, lessThan(yW));
    expect(yW, lessThan(yL));
  });

  testWidgets('no resize option in the tile menu', (tester) async {
    await tester.pumpWidget(
      _harness(
        widgets: [
          _widget(
            id: 'on',
            platform: Platform.steam,
            position: 0,
            size: ProfileWidgetSize.small,
          ),
        ],
        cards: {Platform.steam: _card(Platform.steam)},
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byKey(const Key('profileWidgetMenu_on')));
    await tester.pumpAndSettle();

    // The resize header and the three size items are no longer surfaced; the
    // size tokens stay in the data model for the responsive follow-up.
    expect(find.text(l10n.profileWidgetResize), findsNothing);
    expect(find.text(l10n.profileWidgetSizeSmall), findsNothing);
    expect(find.text(l10n.profileWidgetSizeWide), findsNothing);
    expect(find.text(l10n.profileWidgetSizeLarge), findsNothing);
    // The retained manage affordance is still present.
    expect(find.text(l10n.profileWidgetRemove), findsOneWidget);
  });

  testWidgets('a widget whose card is null renders a placeholder, not a blank '
      'cell', (tester) async {
    final widgets = [
      _widget(
        id: 'present',
        platform: Platform.steam,
        position: 0,
        size: ProfileWidgetSize.small,
      ),
      _widget(
        id: 'missing',
        platform: Platform.chess,
        position: 1,
        size: ProfileWidgetSize.small,
      ),
    ];
    await tester.pumpWidget(
      _harness(
        widgets: widgets,
        cards: {Platform.steam: _card(Platform.steam), Platform.chess: null},
      ),
    );
    await tester.pumpAndSettle();

    // The present card renders; the missing one shows a keyed placeholder
    // (filling its span — the cell is intentional, not a blank hole) and no
    // error tile.
    expect(find.text('${Platform.steam.name}-card'), findsOneWidget);
    expect(find.text('${Platform.chess.name}-card'), findsNothing);
    expect(
      find.byKey(const Key('profileWidgetPlaceholder_missing')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('asyncRetryButton')), findsNothing);
  });

  testWidgets('a null-card widget stays removable', (tester) async {
    await tester.pumpWidget(
      _harness(
        widgets: [
          _widget(
            id: 'missing',
            platform: Platform.chess,
            position: 0,
            size: ProfileWidgetSize.small,
          ),
        ],
        cards: {Platform.chess: null},
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // The options menu is reachable for a null-card widget, so Remove (the only
    // manage affordance) stays usable — a null-card widget must remain
    // removable.
    await tester.tap(find.byKey(const Key('profileWidgetMenu_missing')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.profileWidgetRemove), findsOneWidget);
  });

  testWidgets('a genuine card error still shows the retry affordance', (
    tester,
  ) async {
    final container = ProviderContainer(
      retry: (count, error) => null,
      overrides: [
        cardsRepositoryProvider.overrideWithValue(_ErrorCardsRepository()),
        profileWidgetsRepositoryProvider.overrideWithValue(
          _StubWidgetsRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
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
              child: ProfileWidgetsGrid(
                widgets: [
                  _widget(
                    id: 'err',
                    platform: Platform.steam,
                    position: 0,
                    size: ProfileWidgetSize.small,
                  ),
                ],
                cardBuilder: (card) => Text(card.title),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('asyncRetryButton')), findsOneWidget);
  });

  testWidgets('a disabled widget renders normally and stays manageable', (
    tester,
  ) async {
    final widgets = [
      _widget(
        id: 'on',
        platform: Platform.steam,
        position: 0,
        size: ProfileWidgetSize.small,
      ),
      _widget(
        id: 'off',
        platform: Platform.chess,
        position: 1,
        size: ProfileWidgetSize.small,
        isEnabled: false,
      ),
    ];
    await tester.pumpWidget(
      _harness(
        widgets: widgets,
        cards: {
          Platform.steam: _card(Platform.steam),
          Platform.chess: _card(Platform.chess),
        },
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // An is_enabled=false widget renders like any other — tile and card both
    // present, so a previously-hidden row is not stuck.
    expect(find.byKey(const Key('profileWidgetTile_off')), findsOneWidget);
    expect(find.text('${Platform.chess.name}-card'), findsOneWidget);

    // No reduced-opacity dim is applied to the disabled tile: the only
    // Opacity in its subtree (if any) renders at full opacity.
    final opacities = tester
        .widgetList<Opacity>(
          find.descendant(
            of: find.byKey(const Key('profileWidgetTile_off')),
            matching: find.byType(Opacity),
          ),
        )
        .toList();
    expect(opacities.every((o) => o.opacity == 1.0), isTrue);

    // Its options menu is reachable and Remove stays usable.
    await tester.tap(find.byKey(const Key('profileWidgetMenu_off')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.profileWidgetRemove), findsOneWidget);
  });

  testWidgets('the tile menu offers move/remove only (no hide/show)', (
    tester,
  ) async {
    final widgets = [
      _widget(
        id: 'top',
        platform: Platform.steam,
        position: 0,
        size: ProfileWidgetSize.small,
      ),
      _widget(
        id: 'mid',
        platform: Platform.chess,
        position: 1,
        size: ProfileWidgetSize.small,
      ),
      _widget(
        id: 'bottom',
        platform: Platform.gw2,
        position: 2,
        size: ProfileWidgetSize.small,
      ),
    ];
    await tester.pumpWidget(
      _harness(
        widgets: widgets,
        cards: {
          Platform.steam: _card(Platform.steam),
          Platform.chess: _card(Platform.chess),
          Platform.gw2: _card(Platform.gw2),
        },
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // The middle tile can move both ways, be removed, and customize its data;
    // no hide/show item is surfaced (their l10n keys are gone — assert by the
    // kept items only).
    await tester.tap(find.byKey(const Key('profileWidgetMenu_mid')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.profileWidgetCustomizeData), findsOneWidget);
    expect(find.text(l10n.profileWidgetMoveUp), findsOneWidget);
    expect(find.text(l10n.profileWidgetMoveDown), findsOneWidget);
    expect(find.text(l10n.profileWidgetRemove), findsOneWidget);
    // The menu surfaces exactly the four kept actions — no hide/show item.
    expect(find.bySubtype<PopupMenuItem>(), findsNWidgets(4));
  });

  testWidgets('renders a template-kind tile via TemplateCardView and a '
      'platform-kind tile via cardBuilder', (tester) async {
    final widgets = [
      _widget(
        id: 'plat',
        platform: Platform.steam,
        position: 0,
        size: ProfileWidgetSize.small,
      ),
      _templateWidget(
        id: 'tmpl',
        position: 1,
        fill: const TemplateFill('my_ranks', {'slot_1': 'chess.rating'}),
      ),
    ];
    await tester.pumpWidget(
      _harness(
        widgets: widgets,
        cards: {
          Platform.steam: _card(Platform.steam),
          Platform.chess: _card(
            Platform.chess,
            stats: const [CardStat(key: 'rating', value: 1500)],
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    // The platform tile renders via the injected cardBuilder (its title text).
    expect(find.text('${Platform.steam.name}-card'), findsOneWidget);
    // The template tile renders via TemplateCardView (keyed card + resolved row).
    expect(find.byKey(const Key('templateCard_tmpl')), findsOneWidget);
    expect(
      find.byKey(const Key('templateSlotRow_tmpl_slot_1')),
      findsOneWidget,
    );

    // Both tiles render as full-width column tiles.
    expect(find.byKey(const Key('profileWidgetTile_plat')), findsOneWidget);
    expect(find.byKey(const Key('profileWidgetTile_tmpl')), findsOneWidget);
  });

  testWidgets('a template tile menu offers fill-slots and stays manageable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        widgets: [
          _templateWidget(
            id: 'tmpl',
            position: 0,
            fill: const TemplateFill('my_ranks', {}),
          ),
        ],
        cards: const {},
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byKey(const Key('profileWidgetMenu_tmpl')));
    await tester.pumpAndSettle();

    // The template menu shows Fill slots (not Customize data) and Remove.
    expect(find.text(l10n.templateFillSlots), findsOneWidget);
    expect(find.text(l10n.profileWidgetCustomizeData), findsNothing);
    expect(find.text(l10n.profileWidgetRemove), findsOneWidget);
  });

  testWidgets('a showcase tile routes to ShowcaseCardView and offers size '
      'options, not the other kinds\' customize entries', (tester) async {
    await tester.pumpWidget(
      _harness(
        widgets: [_showcaseWidget(id: 'sc', position: 0)],
        cards: {Platform.steam: _steamShowcaseCard()},
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // The showcase tile renders via ShowcaseCardView (its keyed card).
    expect(find.byKey(const Key('profileWidgetTile_sc')), findsOneWidget);
    expect(find.byKey(const Key('showcaseCard_sc')), findsOneWidget);

    // Its options menu surfaces the three in-card size options plus remove, and
    // none of the other kinds' customize entries.
    await tester.tap(find.byKey(const Key('profileWidgetMenu_sc')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.profileWidgetSizeSmall), findsOneWidget);
    expect(find.text(l10n.profileWidgetSizeWide), findsOneWidget);
    expect(find.text(l10n.profileWidgetSizeLarge), findsOneWidget);
    expect(find.text(l10n.profileWidgetCustomizeData), findsNothing);
    expect(find.text(l10n.templateFillSlots), findsNothing);
    expect(find.text(l10n.composedEditItems), findsNothing);
    expect(find.text(l10n.profileWidgetRemove), findsOneWidget);
  });

  testWidgets('showcase options menu resizes the card via the controller', (
    tester,
  ) async {
    final widgetsRepo = _RecordingWidgetsRepository();
    await tester.pumpWidget(
      _harness(
        widgets: [_showcaseWidget(id: 'sc', position: 0)],
        cards: {Platform.steam: _steamShowcaseCard()},
        widgetsRepo: widgetsRepo,
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Open the menu and pick the wide footprint; the controller drives setSize
    // with that size — the edit-in-card size contract.
    await tester.tap(find.byKey(const Key('profileWidgetMenu_sc')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.profileWidgetSizeWide));
    await tester.pumpAndSettle();

    expect(widgetsRepo.lastSetSize, ProfileWidgetSize.wide);
  });
}
