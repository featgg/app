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
  theme: ProfileTheme.classic,
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
  theme: ProfileTheme.classic,
  privacy: ProfilePrivacy.public,
  featuredPlatform: null,
  layout: [FullRow('w')],
);

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

Widget _screen(
  ProfileRepository profileRepo, {
  String userId = _userId,
  PersonalizationBuilder? personalizationBuilder,
}) {
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
        // A keyed sentinel stands in for the composition-root-injected widgets
        // view; the screen only delegates the body to it.
        widgetsBuilder: (id) =>
            SizedBox(key: Key('widgetsSentinel_$id'), height: 80),
        personalizationBuilder: personalizationBuilder,
      ),
    ),
  );
}

/// A keyed sentinel standing in for the composition-root-injected personalization view.
Widget _personalizationSentinel(Profile profile, String userId) =>
    SizedBox(key: Key('personalizationSentinel_$userId'), height: 80);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  testWidgets('renders identity and delegates the body to widgetsBuilder', (
    tester,
  ) async {
    final profileRepo = _FakeProfileRepository(
      publicResult: (_) async => right(_publicProfile),
    );
    await tester.pumpWidget(_screen(profileRepo));
    await tester.pumpAndSettle();

    // Identity.
    expect(find.text(_publicProfile.displayName), findsOneWidget);
    expect(find.textContaining(_publicProfile.username), findsOneWidget);
    expect(find.text(_publicProfile.bio!), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);

    // The injected widgets body renders, keyed by the screen's userId, below
    // the identity block.
    final sentinel = find.byKey(const Key('widgetsSentinel_$_userId'));
    expect(sentinel, findsOneWidget);
    final yName = tester.getTopLeft(find.text(_publicProfile.displayName)).dy;
    final ySentinel = tester.getTopLeft(sentinel).dy;
    expect(yName, lessThan(ySentinel));

    // The screen body is wrapped in SafeArea (architecture convention).
    expect(
      find.ancestor(
        of: find.text(_publicProfile.displayName),
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
    // No identity fields, and the widgets body is not built for a null profile.
    expect(find.byIcon(Icons.person), findsNothing);
    expect(find.byKey(const Key('widgetsSentinel_$_userId')), findsNothing);
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

  testWidgets('a composed layout routes to the personalization builder', (
    tester,
  ) async {
    final profileRepo = _FakeProfileRepository(
      publicResult: (_) async => right(_layoutProfile),
    );
    await tester.pumpWidget(
      _screen(profileRepo, personalizationBuilder: _personalizationSentinel),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('personalizationSentinel_$_userId')),
      findsOneWidget,
    );
    // The legacy widgets render is bypassed for a composed layout.
    expect(find.byKey(const Key('widgetsSentinel_$_userId')), findsNothing);
  });

  testWidgets('an empty layout keeps the legacy widgets render', (
    tester,
  ) async {
    final profileRepo = _FakeProfileRepository(
      publicResult: (_) async => right(_publicProfile),
    );
    await tester.pumpWidget(
      _screen(profileRepo, personalizationBuilder: _personalizationSentinel),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('widgetsSentinel_$_userId')), findsOneWidget);
    expect(
      find.byKey(const Key('personalizationSentinel_$_userId')),
      findsNothing,
    );
  });
}
