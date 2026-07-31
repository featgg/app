import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/core/theme/personalization_tokens.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/profile.dart';
import 'package:featgg/src/features/profile/domain/profile_composition.dart';
import 'package:featgg/src/features/profile/domain/profile_layout.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_repository.dart';
import 'package:featgg/src/features/profile/presentation/composition_editor_rows.dart';
import 'package:featgg/src/features/profile/presentation/personalization_archetype_cards.dart';
import 'package:featgg/src/features/profile/presentation/profile_composition_controller.dart';
import 'package:featgg/src/features/profile/presentation/profile_widgets_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Serves a fixed set of owner widgets; every mutation is out of scope here.
final class _FakeWidgetsRepository implements ProfileWidgetsRepository {
  _FakeWidgetsRepository(this.widgets);

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

/// No card for any platform, so the seeded Rank/Main cards render their neutral
/// no-data state without any real image decode.
final class _NullCardsRepository implements CardsRepository {
  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) async =>
      right(null);

  @override
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  ) async => right(null);
}

const _rank = ProfileWidget(
  id: 'r',
  kind: ProfileWidgetKind.rank,
  platform: Platform.leagueOfLegends,
  position: 0,
  isEnabled: true,
);

const _main = ProfileWidget(
  id: 'm',
  kind: ProfileWidgetKind.main,
  platform: Platform.steam,
  position: 1,
  isEnabled: true,
);

const _showcase = ProfileWidget(
  id: 's',
  kind: ProfileWidgetKind.showcase,
  platform: Platform.steam,
  position: 2,
  isEnabled: true,
);

/// A profile with no saved arrangement, so the session bootstraps one.
const _unarrangedProfile = Profile(
  id: 'owner-1',
  username: 'nico',
  displayName: 'Nico',
  avatarUrl: null,
  bio: null,
  theme: ProfileTheme.crimson,
  privacy: ProfilePrivacy.public,
  featuredPlatform: null,
);

const double _columnWidth = 360;

Widget _harness(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: PersonalizationTheme(
        palette: PersonalizationPalette.crimson,
        // In production the editor always lives inside the fixed center column;
        // unconstrained, the geometry a drag meets here is not the shipped one.
        child: const SingleChildScrollView(
          child: Center(
            child: SizedBox(
              width: _columnWidth,
              child: CompositionEditorRows(columnWidth: _columnWidth),
            ),
          ),
        ),
      ),
    ),
  ),
);

Future<ProviderContainer> _openEditor(
  WidgetTester tester,
  List<ProfileWidget> widgets,
) async {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      profileWidgetsRepositoryProvider.overrideWithValue(
        _FakeWidgetsRepository(widgets),
      ),
      cardsRepositoryProvider.overrideWithValue(_NullCardsRepository()),
    ],
  );
  addTearDown(container.dispose);

  // Materialize the owner widgets the editor rows read, then seed the editor.
  await container.read(ownerProfileWidgetsProvider.future);
  container
      .read(profileCompositionProvider.notifier)
      .startEditing(_unarrangedProfile, widgets);

  await tester.pumpWidget(_harness(container));
  await tester.pumpAndSettle();
  return container;
}

/// Lift [cardId] by its handle and hold it: past the touch slop, with the
/// opened gaps settled, so the rects a release is computed from are the ones
/// the editor is measuring.
Future<TestGesture> _lift(WidgetTester tester, String cardId) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byKey(Key('compositionDragHandle_$cardId'))),
  );
  await gesture.moveBy(const Offset(0, -20));
  await tester.pump();
  return gesture;
}

Future<void> _releaseAt(
  WidgetTester tester,
  TestGesture gesture,
  Offset point,
) async {
  await gesture.moveTo(point);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

List<ProfileLayoutRow> _working(ProviderContainer container) =>
    container.read(profileCompositionProvider).working;

Finder _vacatedOrigin() => find.byWidgetPredicate(
  (w) => w is Opacity && w.opacity == PersonalizationLayout.editorOriginOpacity,
);

void main() {
  testWidgets(
    'a seeded Rank (now dual-size) shows a size toggle and bootstraps '
    'as a full row, like Main',
    (tester) async {
      final container = await _openEditor(tester, const [_rank, _main]);

      // Rank now supports both sizes → ⇆ toggle present, like Main.
      expect(find.byKey(const Key('compositionSizeToggle_r')), findsOneWidget);
      expect(find.byKey(const Key('compositionSizeToggle_m')), findsOneWidget);

      // The dual-size Rank bootstraps as a full row; the seed reads in category
      // order, so what-I-play (Main) lands before how-good-I-am (Rank).
      expect(_working(container), const [FullRow('m'), FullRow('r')]);
    },
  );

  testWidgets('releasing beside an orphan, not on it, pairs on that side', (
    tester,
  ) async {
    final container = await _openEditor(tester, const [_rank, _main]);
    container.read(profileCompositionProvider.notifier).onToggleSize('r');
    await tester.pumpAndSettle();
    expect(_working(container), const [FullRow('m'), PairRow(left: 'r')]);

    final gesture = await _lift(tester, 'm');
    final orphan = tester.getRect(find.byKey(personalizationCardKey('r')));
    final region = tester.getRect(find.byType(CompositionEditorRows));
    // The column's empty left band, level with the orphan — beside the card,
    // nowhere near on top of it.
    await _releaseAt(
      tester,
      gesture,
      Offset(region.left + 4, orphan.center.dy),
    );

    expect(_working(container), const [PairRow(left: 'm', right: 'r')]);
  });

  testWidgets('releasing over a row that offers nothing lands in the nearest '
      'gap', (tester) async {
    final container = await _openEditor(tester, const [
      _rank,
      _main,
      _showcase,
    ]);
    container
        .read(profileCompositionProvider.notifier)
        .onPairDrop('r', 'm', DropSide.right);
    await tester.pumpAndSettle();
    expect(_working(container), const [
      PairRow(left: 'm', right: 'r'),
      FullRow('s'),
    ]);

    // The pair row is full, so it is no destination for 's' and contributes no
    // zone at all; the gap above it is the nearest landing place.
    final gesture = await _lift(tester, 's');
    final pairRow = tester.getRect(find.byKey(personalizationCardKey('m')));
    await _releaseAt(
      tester,
      gesture,
      Offset(pairRow.center.dx, pairRow.top + 8),
    );

    expect(_working(container), const [
      FullRow('s'),
      PairRow(left: 'm', right: 'r'),
    ]);
  });

  testWidgets('releasing well outside the editor changes nothing', (
    tester,
  ) async {
    final container = await _openEditor(tester, const [_rank, _main]);
    final before = _working(container);

    final gesture = await _lift(tester, 'm');
    final region = tester.getRect(find.byType(CompositionEditorRows));
    await _releaseAt(
      tester,
      gesture,
      Offset(region.center.dx, region.bottom + 200),
    );

    expect(_working(container), before);
  });

  testWidgets('the lifted card is the card', (tester) async {
    await _openEditor(tester, const [_rank, _main]);
    expect(find.byKey(personalizationCardKey('m')), findsOneWidget);

    final gesture = await _lift(tester, 'm');

    // The slot's copy and the one riding under the finger.
    expect(find.byKey(personalizationCardKey('m')), findsNWidgets(2));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('the origin slot reads vacated while the card is in the air', (
    tester,
  ) async {
    await _openEditor(tester, const [_rank, _main]);
    expect(_vacatedOrigin(), findsNothing);

    final gesture = await _lift(tester, 'm');
    expect(_vacatedOrigin(), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(_vacatedOrigin(), findsNothing);
  });

  testWidgets('acquiring a target ticks', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await _openEditor(tester, const [_rank, _main]);
    final gesture = await _lift(tester, 'm');

    expect(
      calls.map((c) => c.method),
      contains('HapticFeedback.vibrate'),
      reason: 'no tick when the drag took a target',
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
