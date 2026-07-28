import 'package:featgg/src/core/core.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/feed/presentation/feed_presentation.dart';
import 'package:featgg/src/features/profile/domain/profile_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Injects a fixed `fetchPublicProfile` outcome per test.
final class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({required this.publicResult});

  final Future<Either<Failure, Profile?>> Function(String userId) publicResult;

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() async =>
      left(const AuthFailure());

  @override
  Future<Either<Failure, Profile>> updateMyProfile(ProfileEdit edit) async =>
      left(const AuthFailure());

  @override
  Future<Either<Failure, Profile?>> fetchPublicProfile(String userId) =>
      publicResult(userId);

  @override
  Future<Either<Failure, Unit>> setMyLayout(
    List<ProfileLayoutRow> rows,
  ) async => right(unit);
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _userId = 'user-public-1';

const _publicProfile = Profile(
  id: _userId,
  username: 'gamer42',
  displayName: 'Gamer 42',
  avatarUrl: null,
  bio: 'I play games.',
  theme: ProfileTheme.crimson,
  privacy: ProfilePrivacy.public,
  featuredPlatform: null,
);

/// The same profile with a composed layout, which must route to the injected
/// personalization builder instead of the legacy widgets render.
const _layoutProfile = Profile(
  id: _userId,
  username: 'gamer42',
  displayName: 'Gamer 42',
  avatarUrl: null,
  bio: 'I play games.',
  theme: ProfileTheme.crimson,
  privacy: ProfilePrivacy.public,
  featuredPlatform: null,
  layout: [FullRow('w')],
);

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

Widget _screen(ProfileRepository profileRepo, {String userId = _userId}) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [profileRepositoryProvider.overrideWithValue(profileRepo)],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PublicProfileScreen(
        userId: userId,
        personalizationBuilder: _personalizationSentinel,
        chromeBuilder: (_) =>
            (background: _chromeBackground, foreground: _chromeForeground),
      ),
    ),
  );
}

/// Stand-ins for the composition-root-injected theme colors, distinct from any
/// default so a bar that ignored them is visible in the assertion.
const _chromeBackground = Color(0xFF123456);
const _chromeForeground = Color(0xFFFEDCBA);

/// A keyed sentinel standing in for the composition-root-injected personalization view.
Widget _personalizationSentinel(Profile profile, String userId) =>
    SizedBox(key: Key('personalizationSentinel_$userId'), height: 80);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  testWidgets('delegates the whole body to the injected render', (
    tester,
  ) async {
    final profileRepo = _FakeProfileRepository(
      publicResult: (_) async => right(_publicProfile),
    );
    await tester.pumpWidget(_screen(profileRepo));
    await tester.pumpAndSettle();

    // One render for every visitor profile: the screen owns the chrome and
    // the unavailable state, and hands everything else to the injected view.
    expect(
      find.byKey(const Key('personalizationSentinel_$_userId')),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.byKey(const Key('personalizationSentinel_$_userId')),
        matching: find.byType(SafeArea),
      ),
      findsWidgets,
    );
  });

  testWidgets('visitor mode hides owner actions', (tester) async {
    final profileRepo = _FakeProfileRepository(
      publicResult: (_) async => right(_publicProfile),
    );
    await tester.pumpWidget(_screen(profileRepo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profileEditButton')), findsNothing);
  });

  testWidgets('private/not-found shows the unavailable state', (tester) async {
    final profileRepo = _FakeProfileRepository(
      publicResult: (_) async => right(null),
    );
    await tester.pumpWidget(_screen(profileRepo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('publicProfileUnavailable')), findsOneWidget);
    // The render is not built at all for a profile that resolves to nothing.
    expect(
      find.byKey(const Key('personalizationSentinel_$_userId')),
      findsNothing,
    );
  });

  testWidgets('loading then error with retry', (tester) async {
    final profileRepo = _FakeProfileRepository(
      publicResult: (_) async => left(const NetworkFailure()),
    );
    await tester.pumpWidget(_screen(profileRepo));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('asyncRetryButton')), findsOneWidget);
  });

  testWidgets('visitor composed render has no compose chrome', (tester) async {
    // The owner's compose entry lives on ProfileScreen; the visitor screen must
    // never surface it, in the composed path or anywhere else.
    final profileRepo = _FakeProfileRepository(
      publicResult: (_) async => right(_layoutProfile),
    );
    await tester.pumpWidget(_screen(profileRepo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profileEditButton')), findsNothing);
  });

  testWidgets('a profile with no saved arrangement still renders', (
    tester,
  ) async {
    // An unarranged profile is not a different kind of profile; it goes
    // through the same render as an arranged one.
    final profileRepo = _FakeProfileRepository(
      publicResult: (_) async => right(_publicProfile),
    );
    await tester.pumpWidget(_screen(profileRepo));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('personalizationSentinel_$_userId')),
      findsOneWidget,
    );
  });

  testWidgets('the app bar takes its colors from the rendered profile theme, '
      'so the chrome does not read as a different page than what is under it', (
    tester,
  ) async {
    final profileRepo = _FakeProfileRepository(
      publicResult: (_) async => right(_publicProfile),
    );
    await tester.pumpWidget(_screen(profileRepo));
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, _chromeBackground);
    expect(appBar.foregroundColor, _chromeForeground);
  });

  testWidgets('a profile that resolves to nothing keeps the default chrome', (
    tester,
  ) async {
    // No profile means no theme to take colors from; borrowing the last one
    // would tint the unavailable state after somebody else's profile.
    final profileRepo = _FakeProfileRepository(
      publicResult: (_) async => right(null),
    );
    await tester.pumpWidget(_screen(profileRepo));
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, isNull);
    expect(appBar.foregroundColor, isNull);
  });
}
