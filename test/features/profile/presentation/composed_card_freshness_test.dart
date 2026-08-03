import 'package:cached_network_image/cached_network_image.dart';
import 'package:clock/clock.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/art_selection.dart';
import 'package:featgg/src/features/profile/domain/profile.dart';
import 'package:featgg/src/features/profile/domain/profile_layout.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_repository.dart';
import 'package:featgg/src/features/profile/presentation/personalization_archetype_cards.dart';
import 'package:featgg/src/features/profile/presentation/personalization_profile_view.dart';
import 'package:featgg/src/features/profile/presentation/profile_owner_cards_provider.dart';
import 'package:featgg/src/features/profile/presentation/public_owner_cards_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

const _userId = 'owner-1';
const _wowArt = 'https://cdn.test/wow-hero.jpg';
const _steamArt = 'https://cdn.test/steam-hero.jpg';

/// The item level the gated card publishes; asserted through the card's own
/// formatter so the check is on the datum rendering, not on a literal.
const _wowItemLevel = 480;

/// The clock every pump runs under, so the fixtures below sit a fixed distance
/// from "now" and the boundary is exercised rather than approximated.
final _now = DateTime.utc(2026, 6, 2);

/// Either side of the 30-day window, so a gate that always fires and a gate that
/// never fires both go red.
final _pastWindow = _now.subtract(const Duration(days: 31));
final _insideWindow = _now.subtract(const Duration(days: 29));

/// Serves the same fixtures on the owner and the public read, so one map backs
/// both viewers and the only difference between them is the injected source.
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
  ) async => right(_cards[platform]);
}

final class _FakeWidgetsRepository implements ProfileWidgetsRepository {
  _FakeWidgetsRepository(this.widgets);

  final List<ProfileWidget> widgets;

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchPublicWidgets(
    String userId,
  ) async => right(widgets);

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets() async =>
      right(widgets);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

GameCard _wowCard(DateTime lastUpdated, {String? heroImage = _wowArt}) =>
    GameCard(
      schemaVersion: 1,
      platform: Platform.wowRetail,
      title: 'wow-card',
      subtitle: null,
      iconImage: null,
      heroImage: heroImage,
      profileUrl: null,
      stats: const [CardStat(key: 'item_level', value: _wowItemLevel)],
      lastUpdated: lastUpdated,
    );

GameCard _steamCard(DateTime lastUpdated) => GameCard(
  schemaVersion: 1,
  platform: Platform.steam,
  title: 'steam-card',
  subtitle: null,
  iconImage: null,
  heroImage: _steamArt,
  profileUrl: null,
  stats: const [CardStat(key: 'games_owned', value: 300)],
  lastUpdated: lastUpdated,
);

ProfileWidget _widget(
  String id,
  ProfileWidgetKind kind, {
  Platform? platform,
  ArtSelection artSelection = ArtSelection.empty,
}) => ProfileWidget(
  id: id,
  kind: kind,
  platform: platform,
  position: 0,
  isEnabled: true,
  artSelection: artSelection,
);

final _widgets = [
  _widget('wow', ProfileWidgetKind.platform, platform: Platform.wowRetail),
  _widget('steam', ProfileWidgetKind.platform, platform: Platform.steam),
  _widget('steam2', ProfileWidgetKind.platform, platform: Platform.steam),
  _widget(
    'art',
    ProfileWidgetKind.art,
    artSelection: const ArtSelection(source: Platform.wowRetail),
  ),
  _widget('passport', ProfileWidgetKind.passport),
];

Profile _profile(List<ProfileLayoutRow> layout) => Profile(
  id: _userId,
  username: 'nico',
  displayName: 'Nico',
  avatarUrl: null,
  bio: null,
  theme: ProfileTheme.crimson,
  privacy: ProfilePrivacy.public,
  featuredPlatform: null,
  layout: layout,
);

/// The visitor's injected source. Null in a pump means the owner's own render,
/// which is the same convention the shipped views use.
CardSource _visitorSource() =>
    (platform) => publicOwnerCardProvider(_userId, platform);

/// Distinguishes one pump's root from the next. Several tests below pump twice
/// to compare two scenarios, and each pump brings its own container: without a
/// fresh key the second one would swap the container under a mounted tree,
/// which is not a state the app can reach and not what these tests measure.
int _pumpSeq = 0;

Future<void> _pump(
  WidgetTester tester, {
  required List<ProfileLayoutRow> layout,
  required Map<Platform, GameCard?> cards,
  CardSource? cardSource,
  double width = 600,
}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      profileWidgetsRepositoryProvider.overrideWithValue(
        _FakeWidgetsRepository(_widgets),
      ),
      cardsRepositoryProvider.overrideWithValue(_FakeCardsRepository(cards)),
    ],
  );
  addTearDown(container.dispose);

  await withClock(Clock.fixed(_now), () async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        key: ValueKey('pump-${_pumpSeq++}'),
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
            body: PersonalizationProfileView(
              profile: _profile(layout),
              userId: _userId,
              cardSource: cardSource,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  });
}

Finder _slot(String id) => find.byKey(personalizationCardKey(id));

Finder _imageFor(String url) =>
    find.byWidgetPredicate((w) => w is CachedNetworkImage && w.imageUrl == url);

double _dy(WidgetTester tester, String id) => tester.getTopLeft(_slot(id)).dy;

double _dx(WidgetTester tester, String id) => tester.getTopLeft(_slot(id)).dx;

/// The card's own formatter, so a datum assertion reads what the card renders
/// rather than pinning the test to one locale's separators.
late AppLocalizations _en;

void main() {
  setUpAll(() async {
    _en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('a stale card is absent for a visitor', (tester) async {
    await _pump(
      tester,
      layout: const [FullRow('wow')],
      cards: {Platform.wowRetail: _wowCard(_pastWindow)},
      cardSource: _visitorSource(),
    );

    expect(_slot('wow'), findsNothing);
    expect(find.byType(PersonalizationStaleCard), findsNothing);
    expect(find.text(formatCardValue(_wowItemLevel, _en)), findsNothing);
  });

  testWidgets('the same card is present at 29 days', (tester) async {
    await _pump(
      tester,
      layout: const [FullRow('wow')],
      cards: {Platform.wowRetail: _wowCard(_insideWindow)},
      cardSource: _visitorSource(),
    );

    expect(_slot('wow'), findsOneWidget);
    expect(find.text(formatCardValue(_wowItemLevel, _en)), findsOneWidget);
  });

  testWidgets('a hidden card leaves no gap in a full row', (tester) async {
    final cards = {
      Platform.wowRetail: _wowCard(_pastWindow),
      Platform.steam: _steamCard(_insideWindow),
    };

    await _pump(
      tester,
      layout: const [FullRow('wow'), FullRow('steam')],
      cards: cards,
      cardSource: _visitorSource(),
    );
    final withHiddenRow = _dy(tester, 'steam');

    await _pump(
      tester,
      layout: const [FullRow('steam')],
      cards: cards,
      cardSource: _visitorSource(),
    );

    // Not merely "higher than a rendered card would put it": the same position
    // the composition has when the stale row was never in the layout.
    expect(withHiddenRow, moreOrLessEquals(_dy(tester, 'steam'), epsilon: 0.5));
  });

  testWidgets('a hidden half centres the surviving card', (tester) async {
    await _pump(
      tester,
      layout: const [
        PairRow(left: 'wow', right: 'steam'),
        FullRow('steam2'),
      ],
      cards: {
        Platform.wowRetail: _wowCard(_pastWindow),
        Platform.steam: _steamCard(_insideWindow),
      },
      cardSource: _visitorSource(),
    );

    expect(_slot('wow'), findsNothing);
    final orphan = tester.getSize(_slot('steam')).width;
    final full = tester.getSize(_slot('steam2')).width;
    expect(orphan, lessThan(full));
    expect(_dx(tester, 'steam'), greaterThan(_dx(tester, 'steam2')));
  });

  testWidgets('the owner keeps the slot and is shown the notice', (
    tester,
  ) async {
    await _pump(
      tester,
      layout: const [FullRow('wow'), FullRow('steam')],
      cards: {
        Platform.wowRetail: _wowCard(_pastWindow),
        Platform.steam: _steamCard(_insideWindow),
      },
    );

    expect(_slot('wow'), findsOneWidget);
    expect(tester.widget(_slot('wow')), isA<PersonalizationStaleCard>());
    // Neither the platform's art nor its numbers reach the withheld slot.
    expect(
      find.descendant(
        of: _slot('wow'),
        matching: find.byType(CachedNetworkImage),
      ),
      findsNothing,
    );
    expect(find.text(formatCardValue(_wowItemLevel, _en)), findsNothing);
    final belowWithheld = _dy(tester, 'steam');

    await _pump(
      tester,
      layout: const [FullRow('wow'), FullRow('steam')],
      cards: {
        Platform.wowRetail: _wowCard(_insideWindow),
        Platform.steam: _steamCard(_insideWindow),
      },
    );

    // The slot keeps its aspect, so nothing under it moves when a card is
    // withheld.
    expect(belowWithheld, moreOrLessEquals(_dy(tester, 'steam'), epsilon: 0.5));
  });

  testWidgets('the owner sees the card as itself at 29 days', (tester) async {
    await _pump(
      tester,
      layout: const [FullRow('wow')],
      cards: {Platform.wowRetail: _wowCard(_insideWindow)},
    );

    expect(find.byType(PersonalizationStaleCard), findsNothing);
    expect(find.text(formatCardValue(_wowItemLevel, _en)), findsOneWidget);
    expect(
      find.descendant(of: _slot('wow'), matching: _imageFor(_wowArt)),
      findsOneWidget,
    );
  });

  testWidgets('an un-gated platform is never withheld', (tester) async {
    for (final source in <CardSource?>[null, _visitorSource()]) {
      await _pump(
        tester,
        layout: const [FullRow('steam')],
        cards: {
          Platform.steam: _steamCard(_now.subtract(const Duration(days: 365))),
        },
        cardSource: source,
      );

      expect(_slot('steam'), findsOneWidget);
      expect(find.byType(PersonalizationStaleCard), findsNothing);
      expect(find.text(formatCardValue(300, _en)), findsOneWidget);
    }
  });

  testWidgets('a stale platform reaches no aggregate surface', (tester) async {
    for (final source in <CardSource?>[null, _visitorSource()]) {
      await _pump(
        tester,
        layout: const [FullRow('passport')],
        cards: {Platform.wowRetail: _wowCard(_pastWindow)},
        cardSource: source,
      );

      // The cover, the marks line and the passport chips all read the same
      // funnel, so the attributed render is drawn nowhere.
      expect(_imageFor(_wowArt), findsNothing);
      expect(
        find.byKey(const Key('personalizationIdentityChip_passport_wowRetail')),
        findsNothing,
      );
    }
  });

  testWidgets('an art card pointed at a stale platform is hidden from a '
      'visitor', (tester) async {
    await _pump(
      tester,
      layout: const [FullRow('art')],
      cards: {Platform.wowRetail: _wowCard(_pastWindow)},
      cardSource: _visitorSource(),
    );

    expect(_slot('art'), findsNothing);
    expect(_imageFor(_wowArt), findsNothing);
  });
}
