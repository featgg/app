import 'dart:async';

import 'package:featgg/src/core/core.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/profile/domain/profile_domain.dart';
import 'package:featgg/src/features/profile/presentation/profile_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

const _profile = Profile(
  id: 'user-1',
  username: 'testuser',
  displayName: 'Test User',
  avatarUrl: null,
  bio: 'My bio',
  theme: ProfileTheme.classic,
  privacy: ProfilePrivacy.public,
);

/// Fake repository; the update outcome is injected per test.
final class _FakeRepository implements ProfileRepository {
  _FakeRepository({required this.updateResult});

  final Either<Failure, Profile> Function() updateResult;

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() async => right(_profile);

  @override
  Future<Either<Failure, Profile>> updateMyProfile(ProfileEdit edit) async =>
      updateResult();
}

/// Holds the update future open so the submitting state stays observable.
final class _PendingRepository implements ProfileRepository {
  final _completer = Completer<Either<Failure, Profile>>();

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() async => right(_profile);

  @override
  Future<Either<Failure, Profile>> updateMyProfile(ProfileEdit edit) =>
      _completer.future;
}

Widget _screen(ProfileRepository repo) {
  final container = ProviderContainer(
    overrides: [profileRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ProfileEditScreen(profile: _profile),
    ),
  );
}

void main() {
  testWidgets('renders the form seeded from the profile', (tester) async {
    await tester.pumpWidget(
      _screen(_FakeRepository(updateResult: () => right(_profile))),
    );
    await tester.pump();

    // Seeded field values are present and the Save action is keyed.
    expect(find.text(_profile.displayName), findsOneWidget);
    expect(find.text(_profile.bio!), findsOneWidget);
    expect(find.byKey(const Key('profileSaveButton')), findsOneWidget);
  });

  testWidgets('a backend failure shows a localized message and keeps input', (
    tester,
  ) async {
    await tester.pumpWidget(
      _screen(_FakeRepository(updateResult: () => left(const InputFailure()))),
    );
    await tester.pump();

    // Make the form dirty so Save is enabled.
    await tester.enterText(
      find.byKey(const Key('profileDisplayNameField')),
      'Changed Name',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('profileSaveButton')));
    await tester.pumpAndSettle();

    // The error node is matched by key, not by literal copy, and the entered
    // display name is still in the field.
    expect(find.byKey(const Key('profileEditErrorText')), findsOneWidget);
    expect(find.text('Changed Name'), findsOneWidget);
  });

  testWidgets('shows a spinner in the Save action while submitting', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(_PendingRepository()));
    await tester.pump();

    // Make the form dirty so Save is enabled.
    await tester.enterText(
      find.byKey(const Key('profileDisplayNameField')),
      'Changed Name',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('profileSaveButton')));
    await tester.pump(); // submitting — the update is still in flight

    expect(
      find.descendant(
        of: find.byKey(const Key('profileSaveButton')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Save is disabled when pristine and enabled after a change', (
    tester,
  ) async {
    await tester.pumpWidget(
      _screen(_FakeRepository(updateResult: () => right(_profile))),
    );
    await tester.pump();

    // Pristine: onPressed must be null (disabled).
    final saveButton = tester.widget<TextButton>(
      find.descendant(
        of: find.byKey(const Key('profileSaveButton')),
        matching: find.byType(TextButton),
      ),
    );
    expect(saveButton.onPressed, isNull);

    // Change the display name — form is now dirty.
    await tester.enterText(
      find.byKey(const Key('profileDisplayNameField')),
      'New Name',
    );
    await tester.pump();

    final saveButtonAfter = tester.widget<TextButton>(
      find.descendant(
        of: find.byKey(const Key('profileSaveButton')),
        matching: find.byType(TextButton),
      ),
    );
    expect(saveButtonAfter.onPressed, isNotNull);
  });

  testWidgets('avatar URL preview renders', (tester) async {
    await tester.pumpWidget(
      _screen(_FakeRepository(updateResult: () => right(_profile))),
    );
    await tester.pump();

    // Preview node is present for the initial empty URL.
    expect(find.byKey(const Key('profileAvatarPreview')), findsOneWidget);

    // Enter a URL and confirm the preview node is still present.
    await tester.enterText(
      find.byKey(const Key('profileAvatarUrlField')),
      'https://example.com/avatar.png',
    );
    await tester.pump();

    expect(find.byKey(const Key('profileAvatarPreview')), findsOneWidget);
  });
}
