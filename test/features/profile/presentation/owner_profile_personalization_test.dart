import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/profile.dart';
import 'package:featgg/src/features/profile/domain/profile_layout.dart';
import 'package:featgg/src/features/profile/domain/profile_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_repository.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_repository.dart';
import 'package:featgg/src/features/profile/presentation/owner_profile_personalization.dart';
import 'package:featgg/src/features/profile/presentation/personalization_archetype_cards.dart';
import 'package:featgg/src/features/profile/presentation/profile_composition_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

// A full-only card ('idc' → identity) and a dual-size card ('card' → fallback).
const _profile = Profile(
  id: 'owner-1',
  username: 'nico',
  displayName: 'Nico',
  avatarUrl: null,
  bio: null,
  theme: ProfileTheme.crimson,
  privacy: ProfilePrivacy.public,
  featuredPlatform: null,
  layout: [FullRow('idc'), FullRow('card')],
);

ProfileWidget _widget(String id, ProfileWidgetKind kind) => ProfileWidget(
  id: id,
  kind: kind,
  platform: null,
  position: 0,
  isEnabled: true,
  size: ProfileWidgetSize.small,
);

final _widgets = [
  _widget('idc', ProfileWidgetKind.passport), // identity → full only
  _widget('card', ProfileWidgetKind.template), // fallback → both sizes
];

final class _FakeProfileRepo implements ProfileRepository {
  _FakeProfileRepo({this.setResult});

  final Either<Failure, Unit> Function()? setResult;

  @override
  Future<Either<Failure, Unit>> setMyLayout(
    List<ProfileLayoutRow> rows,
  ) async => setResult?.call() ?? right(unit);

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() async => right(_profile);

  @override
  Future<Either<Failure, Profile>> updateMyProfile(ProfileEdit edit) async =>
      right(_profile);

  @override
  Future<Either<Failure, Profile?>> fetchPublicProfile(String userId) async =>
      right(null);
}

final class _FakeWidgetsRepo implements ProfileWidgetsRepository {
  _FakeWidgetsRepo(this.widgets);

  final List<ProfileWidget> widgets;

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets() async =>
      right(widgets);

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchPublicWidgets(
    String userId,
  ) async => right(widgets);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

final class _FakeCardsRepo implements CardsRepository {
  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) async =>
      right(null);

  @override
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  ) async => right(null);
}

({Widget widget, ProviderContainer container}) _harness({
  Either<Failure, Unit> Function()? setResult,
}) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      profileRepositoryProvider.overrideWithValue(
        _FakeProfileRepo(setResult: setResult),
      ),
      profileWidgetsRepositoryProvider.overrideWithValue(
        _FakeWidgetsRepo(_widgets),
      ),
      cardsRepositoryProvider.overrideWithValue(_FakeCardsRepo()),
    ],
  );
  addTearDown(container.dispose);
  final widget = UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: OwnerProfilePersonalization(profile: _profile),
      ),
    ),
  );
  return (widget: widget, container: container);
}

/// Pumps in a tall viewport so both composed rows sit on-screen and their
/// in-card handles/toggles are hittable (the default 800×600 view scrolls the
/// second card out of reach).
Future<void> _pump(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(700, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

Future<void> _enterEdit(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('profileComposeEditButton')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('edit mode shows a handle per card and a size toggle only on '
      'dual-size cards', (tester) async {
    await _pump(tester, _harness().widget);

    await _enterEdit(tester);

    // Every card gets a drag handle.
    expect(find.byKey(const Key('compositionDragHandle_idc')), findsOneWidget);
    expect(find.byKey(const Key('compositionDragHandle_card')), findsOneWidget);

    // The size toggle appears only on the dual-size card, never on the
    // full-only identity card.
    expect(find.byKey(const Key('compositionSizeToggle_card')), findsOneWidget);
    expect(find.byKey(const Key('compositionSizeToggle_idc')), findsNothing);
  });

  testWidgets('Done is gated on dirty state', (tester) async {
    await _pump(tester, _harness().widget);
    await _enterEdit(tester);

    // No edit yet → Done is disabled.
    InkWell done() => tester.widget<InkWell>(
      find.byKey(const Key('profileComposeDoneButton')),
    );
    expect(done().onTap, isNull);

    // A size toggle mutates the working layout → Done enables.
    await tester.tap(find.byKey(const Key('compositionSizeToggle_card')));
    await tester.pumpAndSettle();
    expect(done().onTap, isNotNull);
  });

  testWidgets('a save failure surfaces the failure snackbar', (tester) async {
    await _pump(
      tester,
      _harness(setResult: () => left(const NetworkFailure())).widget,
    );
    await _enterEdit(tester);

    // Make a change, then attempt to save.
    await tester.tap(find.byKey(const Key('compositionSizeToggle_card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileComposeDoneButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const Key('profileComposeSaveFailedSnackBar')),
      findsOneWidget,
    );
  });

  testWidgets('leaving edit mode renders the read view (AC7)', (tester) async {
    await _pump(tester, _harness().widget);
    await _enterEdit(tester);

    // Cancel returns to the read render: no drag handles, cards still shown.
    await tester.tap(find.byKey(const Key('profileComposeCancelButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('compositionDragHandle_card')), findsNothing);
    expect(find.byKey(personalizationCardKey('card')), findsOneWidget);
    expect(find.byKey(const Key('profileComposeEditButton')), findsOneWidget);
  });

  testWidgets('dragging a card handle into a gap reorders the layout '
      '(best-effort DnD)', (tester) async {
    final harness = _harness();
    await _pump(tester, harness.widget);
    await _enterEdit(tester);

    // Drag the second card's handle up onto the very first gap.
    final handle = find.byKey(const Key('compositionDragHandle_card'));
    final gap = find.byKey(const Key('compositionGap_0'));
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(gap));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // 'card' moved to the first row.
    final working = harness.container.read(profileCompositionProvider).working;
    expect(working.first, const FullRow('card'));
  });

  testWidgets(
    'the last card clears the floating control bar at maximum scroll',
    (tester) async {
      // Phone-sized viewport with enough full-row cards to scroll past the fold.
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final widgets = [
        for (var i = 0; i < 6; i++) _widget('w$i', ProfileWidgetKind.template),
      ];
      const profile = Profile(
        id: 'owner-1',
        username: 'nico',
        displayName: 'Nico',
        avatarUrl: null,
        bio: null,
        theme: ProfileTheme.crimson,
        privacy: ProfilePrivacy.public,
        featuredPlatform: null,
        layout: [
          FullRow('w0'),
          FullRow('w1'),
          FullRow('w2'),
          FullRow('w3'),
          FullRow('w4'),
          FullRow('w5'),
        ],
      );

      final container = ProviderContainer(
        retry: (count, error) => null,
        overrides: [
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepo()),
          profileWidgetsRepositoryProvider.overrideWithValue(
            _FakeWidgetsRepo(widgets),
          ),
          cardsRepositoryProvider.overrideWithValue(_FakeCardsRepo()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: OwnerProfilePersonalization(profile: profile),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Jump to the very bottom of the scroll content.
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pumpAndSettle();

      // The last card's bottom edge sits above the control bar's top edge — the
      // reserved bottom inset keeps it from hiding behind the bar.
      final lastCardBottom = tester
          .getRect(find.byKey(personalizationCardKey('w5')))
          .bottom;
      final barTop = tester
          .getRect(find.byKey(const Key('profileComposeControlBar')))
          .top;
      expect(lastCardBottom, lessThanOrEqualTo(barTop));
    },
  );
}
