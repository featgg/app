import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/showcase_selection.dart';
import 'package:featgg/src/features/profile/presentation/showcase_card_view.dart';
import 'package:featgg/src/features/profile/presentation/showcase_tint_provider.dart';
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

const _heroUrl = 'https://cdn.example/730/hero.jpg';

GameCard _steamCard({String? heroImage = _heroUrl}) => GameCard(
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
      LibraryShowcaseEntry(
        appId: 730,
        title: 'Counter-Strike 2',
        hours: 1234,
        heroImage: heroImage,
      ),
    ],
    recentGames: const [],
  ),
);

ProfileWidget _showcaseWidget({
  ProfileWidgetSize size = ProfileWidgetSize.large,
  String gameRef = '730',
}) => ProfileWidget(
  id: 's-1',
  kind: ProfileWidgetKind.showcase,
  platform: Platform.steam,
  position: 0,
  isEnabled: true,
  size: size,
  showcaseSelection: ShowcaseSelection(gameRef: gameRef),
);

Widget _app(
  ProviderContainer container,
  ProfileWidget widget, {
  bool showEmptyPlaceholder = true,
}) => UncontrolledProviderScope(
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
        child: ShowcaseCardView(
          widget: widget,
          showEmptyPlaceholder: showEmptyPlaceholder,
        ),
      ),
    ),
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
  return _app(container, widget, showEmptyPlaceholder: showEmptyPlaceholder);
}

Color? _colorOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).style?.color;

void main() {
  group('size-driven text degradation (art never shrinks)', () {
    // Art absent (heroImage null) renders the neutral surface, so no real image
    // is decoded and the identity text is exercised in isolation.
    testWidgets('2x2 (large) shows label + hero + meta with no overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          widget: _showcaseWidget(size: ProfileWidgetSize.large),
          cards: {Platform.steam: _steamCard(heroImage: null)},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('showcaseLabel_s-1')), findsOneWidget);
      expect(find.byKey(const Key('showcaseHero_s-1')), findsOneWidget);
      expect(find.byKey(const Key('showcaseMeta_s-1')), findsOneWidget);
      // The meta line names the stat, so the hero stays the bare value.
      expect(find.text('1234'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('2x1 (wide) shows label + hero inline, no meta, no overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          widget: _showcaseWidget(size: ProfileWidgetSize.wide),
          cards: {Platform.steam: _steamCard(heroImage: null)},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('showcaseLabel_s-1')), findsOneWidget);
      expect(find.byKey(const Key('showcaseHero_s-1')), findsOneWidget);
      expect(find.byKey(const Key('showcaseMeta_s-1')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1x1 (small) shows label + hero, no meta, no overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          widget: _showcaseWidget(size: ProfileWidgetSize.small),
          cards: {Platform.steam: _steamCard(heroImage: null)},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('showcaseLabel_s-1')), findsOneWidget);
      expect(find.byKey(const Key('showcaseHero_s-1')), findsOneWidget);
      expect(find.byKey(const Key('showcaseMeta_s-1')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('label and hero carry the fixture identity values', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          widget: _showcaseWidget(size: ProfileWidgetSize.small),
          cards: {Platform.steam: _steamCard(heroImage: null)},
        ),
      );
      await tester.pumpAndSettle();

      // Fixture-controlled data values (game title uppercased, hero number),
      // not localized copy.
      expect(find.text('COUNTER-STRIKE 2'), findsOneWidget);
      // Small drops the meta line, so the hero carries a unit: the fixture
      // value must be present but no longer renders bare.
      expect(find.text('1234'), findsNothing);
      expect(find.textContaining('1234'), findsOneWidget);
    });
  });

  testWidgets(
    'null art renders a neutral surface with identity text, no image',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          widget: _showcaseWidget(),
          cards: {Platform.steam: _steamCard(heroImage: null)},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('showcaseArt_s-1')), findsOneWidget);
      expect(find.byKey(const Key('showcaseLabel_s-1')), findsOneWidget);
      expect(find.byKey(const Key('showcaseHero_s-1')), findsOneWidget);
      // No broken-image glyph — the neutral surface carries no Image widget.
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an unresolved game shows the owner placeholder', (tester) async {
    await tester.pumpWidget(
      _harness(
        // Game rotated out of the current showcase list.
        widget: _showcaseWidget(gameRef: '999'),
        cards: {Platform.steam: _steamCard(heroImage: null)},
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.byKey(const Key('showcaseEmpty_s-1')), findsOneWidget);
    expect(find.text(l10n.showcaseGameUnavailable), findsOneWidget);
    expect(find.byKey(const Key('showcaseCard_s-1')), findsNothing);
  });

  testWidgets('a null card shows the owner placeholder', (tester) async {
    await tester.pumpWidget(
      _harness(widget: _showcaseWidget(), cards: const {Platform.steam: null}),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('showcaseEmpty_s-1')), findsOneWidget);
    expect(find.byKey(const Key('showcaseCard_s-1')), findsNothing);
  });

  testWidgets(
    'showEmptyPlaceholder:false omits an unresolved card entirely (visitor)',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          widget: _showcaseWidget(gameRef: '999'),
          cards: {Platform.steam: _steamCard(heroImage: null)},
          showEmptyPlaceholder: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('showcaseEmpty_s-1')), findsNothing);
      expect(find.byKey(const Key('showcaseCard_s-1')), findsNothing);
    },
  );

  testWidgets('a resolved card carries no owner-only affordance (parity)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        widget: _showcaseWidget(),
        cards: {Platform.steam: _steamCard(heroImage: null)},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('showcaseCard_s-1')), findsOneWidget);
    // The view itself bakes in no menu/edit control; the owner grid adds it.
    expect(find.byType(PopupMenuButton<Object?>), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('a showcaseTint override colors the label AND hero; meta neutral', (
    tester,
  ) async {
    const tint = Color(0xFFFF0000);
    final container = ProviderContainer(
      retry: (count, error) => null,
      overrides: [
        cardsRepositoryProvider.overrideWithValue(
          _FakeCardsRepository({Platform.steam: _steamCard()}),
        ),
        showcaseTintProvider(_heroUrl).overrideWith((ref) => tint),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      _app(container, _showcaseWidget(size: ProfileWidgetSize.large)),
    );
    // Build and let the (synchronous) tint override resolve; the art loader is
    // not awaited (no real image is decoded).
    await tester.pump();
    await tester.pump();

    final ctx = tester.element(find.byKey(const Key('showcaseCard_s-1')));
    final colorScheme = Theme.of(ctx).colorScheme;

    // Both the label and the hero derive from the extracted tint, so neither is
    // the neutral on-art fallback.
    expect(_colorOf(tester, 'showcaseLabel_s-1'), isNot(colorScheme.onSurface));
    expect(_colorOf(tester, 'showcaseHero_s-1'), isNot(colorScheme.onSurface));
    // The meta stays whisper-quiet neutral (on-art secondary), never tinted.
    // MaterialApp's default theme is light, where the on-art secondary is the
    // inverse role — the text sits on the dark scrim in both themes.
    expect(
      _colorOf(tester, 'showcaseMeta_s-1'),
      colorScheme.onInverseSurface.withValues(alpha: 0.8),
    );

    // Drain any error the un-awaited art loader may surface in the test env.
    tester.takeException();
  });

  testWidgets('the neutral text fallback stays light over the scrim in the '
      'light theme', (tester) async {
    final container = ProviderContainer(
      retry: (count, error) => null,
      overrides: [
        cardsRepositoryProvider.overrideWithValue(
          // No art url → no tint watch → the pure fallback path renders.
          _FakeCardsRepository({Platform.steam: _steamCard(heroImage: null)}),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container, _showcaseWidget()));
    await tester.pumpAndSettle();

    final ctx = tester.element(find.byKey(const Key('showcaseCard_s-1')));
    final colorScheme = Theme.of(ctx).colorScheme;

    // MaterialApp defaults to the light theme, whose onSurface is near-black —
    // unreadable over the always-dark scrim. The fallback must use the light
    // inverse role instead.
    expect(_colorOf(tester, 'showcaseLabel_s-1'), colorScheme.onInverseSurface);
    expect(_colorOf(tester, 'showcaseHero_s-1'), colorScheme.onInverseSurface);
    expect(_colorOf(tester, 'showcaseLabel_s-1'), isNot(colorScheme.onSurface));
  });
}
