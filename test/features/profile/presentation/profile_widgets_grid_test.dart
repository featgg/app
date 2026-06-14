import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_repository.dart';
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
  Future<Either<Failure, ProfileWidget>> addPlatformWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> removeWidget(String id) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setEnabled(String id, bool isEnabled) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setSize(
    String id,
    ProfileWidgetSize size,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> reorder(List<String> orderedIds) async =>
      throw UnimplementedError();
}

GameCard _card(Platform platform) => GameCard(
  schemaVersion: 1,
  platform: platform,
  title: '${platform.name}-card',
  subtitle: null,
  iconImage: null,
  heroImage: null,
  profileUrl: null,
  stats: const [],
  lastUpdated: DateTime.utc(2026, 6, 1),
  data: null,
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
}) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      cardsRepositoryProvider.overrideWithValue(_FakeCardsRepository(cards)),
      profileWidgetsRepositoryProvider.overrideWithValue(
        _StubWidgetsRepository(),
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
          child: ProfileWidgetsGrid(
            widgets: widgets,
            // A full-height card stand-in (the real connections card is tall):
            // gives the tile enough content height for the options-menu overlay
            // to sit within its bounds, and keeps the title assertable.
            cardBuilder: (card) =>
                SizedBox(height: 200, child: Text(card.title)),
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
    // The retained affordances are still present.
    expect(find.text(l10n.profileWidgetHide), findsOneWidget);
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

  testWidgets(
    'a hidden widget stays in the grid, dimmed, so it is reversible',
    (tester) async {
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

      // Both tiles render — hiding does not remove the widget from the grid.
      expect(find.byKey(const Key('profileWidgetTile_on')), findsOneWidget);
      expect(find.byKey(const Key('profileWidgetTile_off')), findsOneWidget);

      // The hidden tile's card is dimmed; the enabled one is at full opacity.
      final hiddenOpacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byKey(const Key('profileWidgetTile_off')),
          matching: find.byType(Opacity),
        ),
      );
      final shownOpacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byKey(const Key('profileWidgetTile_on')),
          matching: find.byType(Opacity),
        ),
      );
      expect(hiddenOpacity.opacity, lessThan(shownOpacity.opacity));
    },
  );

  testWidgets('an enabled tile offers Hide, not Show', (tester) async {
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
    expect(find.text(l10n.profileWidgetHide), findsOneWidget);
    expect(find.text(l10n.profileWidgetShow), findsNothing);
  });

  testWidgets('a hidden tile offers a reachable Show (re-enable) path', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        widgets: [
          _widget(
            id: 'off',
            platform: Platform.steam,
            position: 0,
            size: ProfileWidgetSize.small,
            isEnabled: false,
          ),
        ],
        cards: {Platform.steam: _card(Platform.steam)},
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byKey(const Key('profileWidgetMenu_off')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.profileWidgetShow), findsOneWidget);
    expect(find.text(l10n.profileWidgetHide), findsNothing);
  });
}
