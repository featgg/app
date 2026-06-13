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
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
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
            // Identifiable renderer so card presence is assertable.
            cardBuilder: (card) => Text(card.title),
          ),
        ),
      ),
    ),
  );
}

StaggeredGridTile _tileFor(WidgetTester tester, String id) =>
    tester.widget<StaggeredGridTile>(find.byKey(Key('profileWidgetTile_$id')));

void main() {
  testWidgets('maps each size token to the expected tile spans', (
    tester,
  ) async {
    final widgets = [
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
      _widget(
        id: 'l',
        platform: Platform.gw2,
        position: 2,
        size: ProfileWidgetSize.large,
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

    final small = _tileFor(tester, 's');
    expect(small.crossAxisCellCount, 1);
    expect(small.mainAxisCellCount, 1);

    final wide = _tileFor(tester, 'w');
    expect(wide.crossAxisCellCount, 2);
    expect(wide.mainAxisCellCount, 1);

    final large = _tileFor(tester, 'l');
    expect(large.crossAxisCellCount, 2);
    expect(large.mainAxisCellCount, 2);
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
    // manage affordance) stays usable — this is what F4 restores.
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
