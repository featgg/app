import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/core/theme/personalization_tokens.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/profile.dart';
import 'package:featgg/src/features/profile/presentation/profile_composition_controller.dart';
import 'package:featgg/src/features/profile/presentation/profile_edit_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Serves the owner's own cards; the cover chooser reads no other source.
final class _OwnerCardsRepository implements CardsRepository {
  _OwnerCardsRepository(this._cards);

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

Profile _profile({String? bio, Platform? header}) => Profile(
  id: 'owner-1',
  username: 'nico',
  displayName: 'Nico',
  avatarUrl: null,
  bio: bio,
  theme: ProfileTheme.crimson,
  privacy: ProfilePrivacy.public,
  featuredPlatform: null,
  headerPlatform: header,
);

/// Hosts the three in-place editors over an open edit session, the way the
/// profile does: the controls read and write the session's draft, never the
/// network.
Future<ProviderContainer> _host(
  WidgetTester tester, {
  Profile? profile,
  Map<Platform, GameCard?> cards = const {},
}) async {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      cardsRepositoryProvider.overrideWithValue(_OwnerCardsRepository(cards)),
    ],
  );
  addTearDown(container.dispose);
  container
      .read(profileCompositionProvider.notifier)
      .startEditing(profile ?? _profile(), const []);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PersonalizationTheme(
            palette: PersonalizationPalette.crimson,
            child: Builder(
              builder: (context) => Column(
                children: [
                  TextButton(
                    key: const Key('openIdentity'),
                    onPressed: () => showProfileIdentitySheet(context),
                    child: const SizedBox.shrink(),
                  ),
                  TextButton(
                    key: const Key('openCover'),
                    onPressed: () => showProfileCoverSheet(context),
                    child: const SizedBox.shrink(),
                  ),
                  const ProfileThemeStrip(),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

ProfileEdit? _draft(ProviderContainer container) =>
    container.read(profileCompositionProvider).draft;

void main() {
  group('the name-and-bio sheet', () {
    testWidgets('applies to the draft and closes, writing nothing', (
      tester,
    ) async {
      final container = await _host(tester);

      await tester.tap(find.byKey(const Key('openIdentity')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('profileDisplayNameField')),
        'Nico F',
      );
      await tester.enterText(find.byKey(const Key('profileBioField')), 'gg');
      await tester.tap(find.byKey(const Key('profileEditIdentityDoneButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profileEditIdentitySheet')), findsNothing);
      expect(_draft(container)?.displayName, 'Nico F');
      expect(_draft(container)?.bio, 'gg');
    });

    testWidgets('an emptied bio clears it rather than storing a blank', (
      tester,
    ) async {
      final container = await _host(tester, profile: _profile(bio: 'old bio'));

      await tester.tap(find.byKey(const Key('openIdentity')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('profileBioField')), '   ');
      await tester.tap(find.byKey(const Key('profileEditIdentityDoneButton')));
      await tester.pumpAndSettle();

      expect(_draft(container)?.bio, isNull);
    });

    testWidgets('an invalid name holds the sheet open and leaves the draft '
        'alone', (tester) async {
      // The draft only ever holds a submittable edit, so the session's Done
      // never has to answer for a name the backend would reject.
      final container = await _host(tester);

      await tester.tap(find.byKey(const Key('openIdentity')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('profileDisplayNameField')),
        '   ',
      );
      await tester.tap(find.byKey(const Key('profileEditIdentityDoneButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profileEditIdentitySheet')), findsOneWidget);
      expect(_draft(container)?.displayName, 'Nico');
    });
  });

  group('the cover chooser', () {
    testWidgets('offers automatic and only the platforms that publish art', (
      tester,
    ) async {
      await _host(
        tester,
        cards: {
          Platform.steam: _card(
            Platform.steam,
            heroImage: 'https://cdn.test/steam.jpg',
          ),
          // Linked but publishing nothing: picking it would leave the cover
          // exactly as it is, so it is not offered.
          Platform.chess: _card(Platform.chess),
        },
      );

      await tester.tap(find.byKey(const Key('openCover')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profileEditCoverOption_auto')), findsOne);
      expect(find.byKey(const Key('profileEditCoverOption_steam')), findsOne);
      expect(
        find.byKey(const Key('profileEditCoverOption_chess')),
        findsNothing,
      );
    });

    testWidgets('still lists the stored choice when it publishes nothing '
        'today', (tester) async {
      // A preference the owner made stays visible, and therefore clearable —
      // dropping it would strand the profile on a choice with no row to undo.
      await _host(
        tester,
        profile: _profile(header: Platform.chess),
        cards: {Platform.chess: _card(Platform.chess)},
      );

      await tester.tap(find.byKey(const Key('openCover')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profileEditCoverOption_chess')), findsOne);
    });

    testWidgets('a pick lands in the draft and closes the sheet', (
      tester,
    ) async {
      final container = await _host(
        tester,
        cards: {
          Platform.steam: _card(
            Platform.steam,
            heroImage: 'https://cdn.test/steam.jpg',
          ),
        },
      );

      await tester.tap(find.byKey(const Key('openCover')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profileEditCoverOption_steam')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profileEditCoverSheet')), findsNothing);
      expect(_draft(container)?.headerPlatform, Platform.steam);
    });

    testWidgets('automatic clears a stored choice', (tester) async {
      final container = await _host(
        tester,
        profile: _profile(header: Platform.steam),
        cards: {
          Platform.steam: _card(
            Platform.steam,
            heroImage: 'https://cdn.test/steam.jpg',
          ),
        },
      );

      await tester.tap(find.byKey(const Key('openCover')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profileEditCoverOption_auto')));
      await tester.pumpAndSettle();

      expect(_draft(container)?.headerPlatform, isNull);
    });
  });

  group('the theme strip', () {
    testWidgets('a swatch tap re-themes the draft', (tester) async {
      final container = await _host(tester);

      await tester.tap(
        find.byKey(const Key('profileEditThemeSwatch_abyss')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(_draft(container)?.theme, ProfileTheme.abyss);
    });

    testWidgets('shows nothing outside an edit session', (tester) async {
      // No draft means no theme to pick against; the strip belongs to the
      // session, not to the profile.
      final container = ProviderContainer(retry: (count, error) => null);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: PersonalizationTheme(
                palette: PersonalizationPalette.crimson,
                child: ProfileThemeStrip(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profileEditThemeStrip')), findsNothing);
    });
  });
}
