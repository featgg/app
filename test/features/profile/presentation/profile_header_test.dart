import 'dart:math' as math;

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
import 'package:featgg/src/features/profile/presentation/personalization_theme_palette.dart';
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
  Platform? header,
}) => Profile(
  id: _userId,
  username: username,
  displayName: displayName,
  avatarUrl: avatarUrl,
  bio: bio,
  theme: ProfileTheme.crimson,
  privacy: ProfilePrivacy.public,
  featuredPlatform: featured,
  headerPlatform: header,
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
  ProfileHeaderEditing? editing,
  // An in-flight upload spins forever by design, so its frames are pumped
  // rather than settled.
  bool settle = true,
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
                  editing: editing,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
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

/// WCAG relative luminance of one channel.
double _channel(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

/// [over] composited onto [under], for a surface token that is translucent.
Color _composite(Color over, Color under) => Color.from(
  alpha: 1,
  red: over.r * over.a + under.r * (1 - over.a),
  green: over.g * over.a + under.g * (1 - over.a),
  blue: over.b * over.a + under.b * (1 - over.a),
);

/// WCAG contrast ratio between two opaque colors.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

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

  group('legibility', () {
    testWidgets('the handle clears AA against the surface it sits on', (
      tester,
    ) async {
      // The identity moved onto solid ground, which is what makes contrast
      // assertable at all — over art it depended on whatever the art was.
      await _pump(tester, profile: _profile());

      const palette = PersonalizationPalette.crimson;
      final handle = tester
          .widget<Text>(find.byKey(kProfileHeaderHandleKey))
          .style!;
      final ground = _composite(palette.surface, palette.bg);

      expect(
        _contrast(handle.color!, ground),
        greaterThanOrEqualTo(4.5),
        reason: 'small text needs 4.5:1; the brand accent lands near 3.4:1',
      );
    });

    test('every curated theme keeps the secondary text tone legible', () {
      // The header reads its secondary lines from `muted`. Shared across the
      // eight palettes today, so this goes red the day one of them diverges
      // into something that no longer carries small text.
      for (final theme in ProfileTheme.values) {
        final palette = paletteForTheme(theme);
        final ground = _composite(palette.surface, palette.bg);

        expect(
          _contrast(palette.muted, ground),
          greaterThanOrEqualTo(4.5),
          reason: '${theme.name} fails AA for small text',
        );
      }
    });
  });

  group('cover', () {
    testWidgets('is wide and shallow, not a block the cards sit below', (
      tester,
    ) async {
      const column = 400.0;
      await _pump(tester, profile: _profile(), columnWidth: column);

      final cover = tester.getSize(find.byKey(kProfileHeaderCoverKey));

      expect(cover.width, moreOrLessEquals(column, epsilon: 0.5));
      expect(
        cover.height,
        moreOrLessEquals(
          column / PersonalizationLayout.coverAspect,
          epsilon: 0.5,
        ),
      );
      // The whole point of the shape: the header cannot fill a phone screen.
      expect(cover.height, lessThan(column / 2));
    });

    testWidgets('the avatar straddles the seam rather than sitting below it', (
      tester,
    ) async {
      const column = 400.0;
      await _pump(tester, profile: _profile(), columnWidth: column);

      final coverBottom = tester
          .getRect(find.byKey(kProfileHeaderCoverKey))
          .bottom;
      final avatar = tester.getRect(find.byKey(kProfileHeaderAvatarKey));

      expect(avatar.top, lessThan(coverBottom));
      expect(avatar.bottom, greaterThan(coverBottom));
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

    testWidgets('the owner\'s chosen platform wins over the featured one', (
      tester,
    ) async {
      await _pump(
        tester,
        profile: _profile(featured: Platform.steam, header: Platform.wowRetail),
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

      // Rendered as written, not uppercased: at strip height the header reads
      // as an identity line rather than a display banner.
      expect(_textAt(tester, kProfileHeaderNameKey), 'nico');
    });
  });

  testWidgets('the header fits at the narrowest column', (tester) async {
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

  group('editing in place', () {
    testWidgets('a header that is only read offers nothing to tap', (
      tester,
    ) async {
      // The same header renders for a visitor. Edit affordances appearing there
      // would offer to change somebody else's profile.
      await _pump(tester, profile: _profile(avatarUrl: _avatarUrl));

      for (final key in const [
        'profileHeaderCoverEditTarget',
        'profileHeaderAvatarEditTarget',
        'profileHeaderIdentityEditTarget',
      ]) {
        expect(find.byKey(Key(key)), findsNothing, reason: key);
      }
    });

    testWidgets('each part the header shows opens its own editor', (
      tester,
    ) async {
      final tapped = <String>[];
      await _pump(
        tester,
        profile: _profile(avatarUrl: _avatarUrl),
        editing: ProfileHeaderEditing(
          onEditAvatar: () => tapped.add('avatar'),
          onEditCover: () => tapped.add('cover'),
          onEditIdentity: () => tapped.add('identity'),
        ),
      );

      await tester.tap(find.byKey(const Key('profileHeaderCoverEditTarget')));
      await tester.tap(find.byKey(const Key('profileHeaderAvatarEditTarget')));
      await tester.tap(
        find.byKey(const Key('profileHeaderIdentityEditTarget')),
      );
      await tester.pump();

      // Three separate things to change, three separate targets — not one
      // "edit the header" tap that then asks which part was meant.
      expect(tapped, ['cover', 'avatar', 'identity']);
    });

    testWidgets('the avatar takes no further taps while its photo uploads', (
      tester,
    ) async {
      final tapped = <String>[];
      await _pump(
        tester,
        profile: _profile(avatarUrl: _avatarUrl),
        editing: ProfileHeaderEditing(
          avatarBusy: true,
          onEditAvatar: () => tapped.add('avatar'),
          onEditCover: () {},
          onEditIdentity: () {},
        ),
        settle: false,
      );

      await tester.tap(find.byKey(const Key('profileHeaderAvatarEditTarget')));
      await tester.pump();

      expect(tapped, isEmpty);
      // Progress replaces the pencil on the avatar's own badge, so the owner
      // sees where the wait belongs rather than a header that just went inert.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
