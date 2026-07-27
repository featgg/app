import 'package:cached_network_image/cached_network_image.dart';
import 'package:clock/clock.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/core/theme/personalization_tokens.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/connections/domain/platform_descriptor.dart';
import 'package:featgg/src/features/profile/domain/profile.dart';
import 'package:featgg/src/features/profile/presentation/profile_header.dart';
import 'package:featgg/src/features/profile/presentation/public_owner_cards_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

const _userId = 'owner-1';
const _avatarUrl = 'https://cdn.test/avatar.jpg';
const _steamArt = 'https://cdn.test/steam-hero.jpg';
const _wowArt = 'https://cdn.test/wow-hero.jpg';

/// Serves the injected cards on the public read; `fetchMyCard` is always null so
/// a test proves the header binds to the injected source.
final class _PublicCardsRepository implements CardsRepository {
  _PublicCardsRepository(this._public);

  final Map<Platform, GameCard?> _public;

  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) async =>
      right(null);

  @override
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  ) async => right(_public[platform]);
}

/// The clock every pump runs under. Pinned because the visitor read hides a
/// stale card, which would otherwise turn a fixture's fixed timestamp into a
/// test that passes today and fails a month from now.
final _now = DateTime.utc(2026, 6, 2);

GameCard _card(Platform platform, {String? heroImage}) => GameCard(
  schemaVersion: 1,
  platform: platform,
  title: '${platform.name}-card',
  subtitle: null,
  iconImage: null,
  heroImage: heroImage,
  profileUrl: null,
  stats: const [],
  lastUpdated: DateTime.utc(2026, 6, 1),
);

Profile _profile({
  String displayName = 'Nico',
  String username = 'nico',
  String? avatarUrl,
  String? bio,
  Platform? featured,
}) => Profile(
  id: _userId,
  username: username,
  displayName: displayName,
  avatarUrl: avatarUrl,
  bio: bio,
  theme: ProfileTheme.crimson,
  privacy: ProfilePrivacy.public,
  featuredPlatform: featured,
  createdAt: DateTime.utc(2025, 3, 1),
);

/// Renders the header at [columnWidth] inside a viewport tall enough that the
/// art frame gets its full budget, unless [screenHeight] narrows it.
Future<void> _pump(
  WidgetTester tester, {
  required Profile profile,
  Map<Platform, GameCard?> cards = const {},
  double columnWidth = PersonalizationLayout.columnMaxWidth,
  double screenHeight = 2000,
}) async {
  tester.view.physicalSize = Size(columnWidth, screenHeight);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      cardsRepositoryProvider.overrideWithValue(_PublicCardsRepository(cards)),
    ],
  );
  addTearDown(container.dispose);

  await withClock(Clock.fixed(_now), () async {
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
            body: PersonalizationTheme(
              palette: PersonalizationPalette.crimson,
              child: SizedBox(
                width: columnWidth,
                child: ProfileHeader(
                  profile: profile,
                  columnWidth: columnWidth,
                  cardSource: (platform) =>
                      publicOwnerCardProvider(_userId, platform),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  });
}

Finder _imageFor(String url) =>
    find.byWidgetPredicate((w) => w is CachedNetworkImage && w.imageUrl == url);

String _textAt(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

/// The rendered marks, one per entry. Read as a list rather than compared to a
/// written-out line so what is asserted is which platforms are named and in
/// what order — revising a brand's short form is a copy call, not a regression.
List<String> _marks(WidgetTester tester) =>
    _textAt(tester, kProfileHeaderMarksKey).split(' · ');

String _mark(Platform platform) =>
    platformDescriptors[platform]!.shortName.toUpperCase();

void main() {
  group('avatar', () {
    testWidgets('renders the profile\'s own image when it has one', (
      tester,
    ) async {
      await _pump(tester, profile: _profile(avatarUrl: _avatarUrl));

      expect(
        find.descendant(
          of: find.byKey(kProfileHeaderAvatarKey),
          matching: _imageFor(_avatarUrl),
        ),
        findsOneWidget,
      );
    });

    testWidgets('falls back to the monogram with no image', (tester) async {
      await _pump(tester, profile: _profile(displayName: 'Nico'));

      expect(
        find.descendant(
          of: find.byKey(kProfileHeaderAvatarKey),
          matching: find.text('N'),
        ),
        findsOneWidget,
      );
    });
  });

  group('marks', () {
    testWidgets('one per linked platform, and none for the rest', (
      tester,
    ) async {
      await _pump(
        tester,
        profile: _profile(),
        cards: {
          Platform.steam: _card(Platform.steam),
          Platform.wowRetail: _card(Platform.wowRetail),
          Platform.chess: null,
        },
      );

      expect(_marks(tester), [
        _mark(Platform.steam),
        _mark(Platform.wowRetail),
      ]);
    });

    testWidgets('a mark is the platform\'s short form, not its full title', (
      tester,
    ) async {
      await _pump(
        tester,
        profile: _profile(),
        cards: {Platform.wowRetail: _card(Platform.wowRetail)},
      );

      final descriptor = platformDescriptors[Platform.wowRetail]!;
      final line = _textAt(tester, kProfileHeaderMarksKey);

      expect(line, contains(descriptor.shortName.toUpperCase()));
      // The full title is what the retired identity card showed. On one line
      // beside the other marks it would push them off the header.
      expect(line, isNot(contains(descriptor.displayName.toUpperCase())));
    });

    testWidgets('a profile with nothing linked shows no marks line', (
      tester,
    ) async {
      await _pump(tester, profile: _profile());

      expect(find.byKey(kProfileHeaderMarksKey), findsNothing);
    });
  });

  group('art', () {
    testWidgets('defaults to the featured platform\'s art', (tester) async {
      await _pump(
        tester,
        profile: _profile(featured: Platform.wowRetail),
        cards: {
          Platform.steam: _card(Platform.steam, heroImage: _steamArt),
          Platform.wowRetail: _card(Platform.wowRetail, heroImage: _wowArt),
        },
      );

      expect(_imageFor(_wowArt), findsWidgets);
      expect(_imageFor(_steamArt), findsNothing);
    });

    testWidgets(
      'falls to another linked platform when the featured one has none',
      (tester) async {
        await _pump(
          tester,
          profile: _profile(featured: Platform.chess),
          cards: {
            Platform.steam: _card(Platform.steam, heroImage: _steamArt),
            Platform.chess: _card(Platform.chess),
          },
        );

        expect(_imageFor(_steamArt), findsWidgets);
      },
    );
  });

  group('name', () {
    testWidgets('falls back to the handle when the display name is empty', (
      tester,
    ) async {
      await _pump(
        tester,
        profile: _profile(displayName: '', username: 'nico'),
      );

      expect(_textAt(tester, kProfileHeaderNameKey), 'NICO');
    });
  });

  testWidgets('the identity fits the art frame at the narrowest column', (
    tester,
  ) async {
    // Everything the header can carry at once, on the smallest phone the
    // profile is designed for and a viewport short enough to shorten the frame:
    // the identity stack has to fit the art rather than overflow it.
    await _pump(
      tester,
      profile: _profile(
        displayName: 'Nicolas',
        avatarUrl: _avatarUrl,
        bio: 'Chasing perfect runs and unreasonable backlogs.',
      ),
      cards: {
        for (final platform in Platform.values) platform: _card(platform),
      },
      columnWidth:
          PersonalizationLayout.columnMinWidth -
          2 * PersonalizationLayout.columnSidePadding,
      screenHeight: 480,
    );

    expect(tester.takeException(), isNull);
  });
}
