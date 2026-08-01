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

/// Serves the owner widgets and honours a delete, which is the one mutation the
/// editor can reach while a card is in the air.
final class _FakeWidgetsRepository implements ProfileWidgetsRepository {
  _FakeWidgetsRepository(Iterable<ProfileWidget> widgets)
    : widgets = [...widgets];

  final List<ProfileWidget> widgets;

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets() async =>
      right([...widgets]);

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchPublicWidgets(
    String userId,
  ) async => right([...widgets]);

  @override
  Future<Either<Failure, Unit>> removeWidget(String id) async {
    widgets.removeWhere((w) => w.id == id);
    return right(unit);
  }

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

/// Identity is full-only per the archetype registry, so no row ever offers it
/// a pair slot.
const _identity = ProfileWidget(
  id: 'i',
  kind: ProfileWidgetKind.passport,
  platform: null,
  position: 3,
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

Widget _harness(ProviderContainer container, {required bool reducedMotion}) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            // Copied from the ambient data rather than built fresh: a bare
            // MediaQueryData zeroes the viewport the drag's auto-scroll is
            // measured against.
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reducedMotion),
              child: PersonalizationTheme(
                palette: PersonalizationPalette.crimson,
                // In production the editor always lives inside the fixed center
                // column; unconstrained, the geometry a drag meets here is not
                // the shipped one.
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
        ),
      ),
    );

Future<ProviderContainer> _openEditor(
  WidgetTester tester,
  List<ProfileWidget> widgets, {
  bool reducedMotion = false,
}) async {
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

  await tester.pumpWidget(_harness(container, reducedMotion: reducedMotion));
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

/// The accent line the editor draws inside the gap it holds. The gap itself
/// carries no decoration, so its only decorated descendant is that line.
Finder _gapMark(int index) => find.descendant(
  of: find.byKey(Key('compositionGap_$index')),
  matching: find.byType(DecoratedBox),
);

/// The accent bar the editor draws down the drop side of the card a pair drop
/// is aimed at.
Finder _pairMark(String cardId) =>
    find.byKey(Key('compositionMark_pair_$cardId'));

/// Every landing indicator on screen, whichever zone holds it.
Finder _anyMark() => find.byWidgetPredicate((w) {
  final key = w.key;
  return key is ValueKey<String> && key.value.startsWith('compositionMark_');
});

/// The pulse wired onto a landing mark. Nothing else inside the editor fades,
/// so this is the animation's whole footprint.
Finder _pulseTransitions() => find.descendant(
  of: find.byType(CompositionEditorRows),
  matching: find.byType(FadeTransition),
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

  testWidgets('a half card released into a gap stays half', (tester) async {
    final container = await _openEditor(tester, const [
      _rank,
      _main,
      _showcase,
    ]);
    container.read(profileCompositionProvider.notifier).onToggleSize('r');
    await tester.pumpAndSettle();
    expect(_working(container), const [
      FullRow('m'),
      PairRow(left: 'r'),
      FullRow('s'),
    ]);

    final gesture = await _lift(tester, 'r');
    // Measured after the lift, so the grown gaps are the ones scored; the
    // bottom-biased point keeps the rival row-2 zone clear of the deadband.
    final gap = tester.getRect(find.byKey(const Key('compositionGap_3')));
    await _releaseAt(tester, gesture, Offset(gap.center.dx, gap.bottom - 1));

    // Rank supports both sizes, so a rule reading the archetype would land it
    // full; it stays the half it was lifted as.
    expect(_working(container), const [
      FullRow('m'),
      FullRow('s'),
      PairRow(left: 'r'),
    ]);
  });

  testWidgets('exactly one landing indicator is shown while a card is in the '
      'air', (tester) async {
    await _openEditor(tester, const [_rank, _main, _showcase]);

    final gesture = await _lift(tester, 'm');
    final target = tester.getRect(find.byKey(personalizationCardKey('r')));
    await gesture.moveTo(Offset(target.left + 8, target.center.dy));
    await tester.pump();

    // The Showcase row below accepts a pair too and stays unmarked: what is
    // held is the only thing highlighted.
    expect(_anyMark(), findsOneWidget);
    expect(_pairMark('r'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('the pair mark sits beside the target card, never over it', (
    tester,
  ) async {
    await _openEditor(tester, const [_rank, _main, _showcase]);

    final gesture = await _lift(tester, 'm');
    final aimedAt = tester.getRect(find.byKey(personalizationCardKey('r')));
    await gesture.moveTo(Offset(aimedAt.left + 8, aimedAt.center.dy));
    await tester.pump();

    final card = tester.getRect(find.byKey(personalizationCardKey('r')));
    final mark = tester.getRect(_pairMark('r'));
    // A bar, not a border or a ring: taller than it is wide, shorter than the
    // card, and drawn in the channel beside the card on the side the release
    // would land — clear of the art, and near enough to belong to that card.
    expect(mark.width, lessThan(mark.height));
    expect(mark.height, lessThan(card.height));
    expect(mark.overlaps(card), isFalse);
    expect(mark.right, lessThanOrEqualTo(card.left));
    expect(
      card.left - mark.right,
      lessThan(PersonalizationLayout.columnSidePadding),
    );

    await gesture.moveTo(Offset(card.right - 8, card.center.dy));
    await tester.pump();
    expect(
      tester.getRect(_pairMark('r')).left,
      greaterThanOrEqualTo(
        tester.getRect(find.byKey(personalizationCardKey('r'))).right,
      ),
    );

    // getRect reads a render object's transform and size, not painted pixels,
    // so every expectation above would still hold with the bar clipped out of
    // existence by the slot it is drawn outside of.
    final slot = tester.widget<Stack>(
      find.ancestor(of: _pairMark('r'), matching: find.byType(Stack)).first,
    );
    expect(slot.clipBehavior, Clip.none);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('the mark keeps the same proportion of a half target and a full '
      'one', (tester) async {
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

    // One drag that meets both target sizes: 'r' may pair with its own partner
    // (a half) and with the row below (a full).
    final gesture = await _lift(tester, 'r');

    final half = tester.getRect(find.byKey(personalizationCardKey('m')));
    await gesture.moveTo(Offset(half.left + 8, half.center.dy));
    await tester.pump();
    final halfRatio = tester.getRect(_pairMark('m')).height / half.height;

    final full = tester.getRect(find.byKey(personalizationCardKey('s')));
    await gesture.moveTo(Offset(full.left + 8, full.center.dy));
    await tester.pump();
    final fullRatio = tester.getRect(_pairMark('s')).height / full.height;

    // The owner must read one object whatever it marks; a mark held off the
    // ends by a fixed amount is a different fraction of every card height.
    expect(fullRatio, closeTo(halfRatio, 0.005));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a card that can pair with nothing only ever marks gaps', (
    tester,
  ) async {
    await _openEditor(tester, const [_rank, _identity]);

    final gesture = await _lift(tester, 'i');
    final target = tester.getRect(find.byKey(personalizationCardKey('r')));
    await gesture.moveTo(target.center);
    await tester.pump();

    // No row offers a full-only card a pair slot, so aiming at a card hands
    // the release to the gap beside it — the whole of the negative signal now
    // that nothing is highlighted on lift.
    expect(_pairMark('r'), findsNothing);
    expect(_anyMark(), findsOneWidget);
    expect(
      (tester.widget(_anyMark()).key! as ValueKey<String>).value,
      startsWith('compositionMark_gap_'),
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('the pulse stops when the drag ends', (tester) async {
    await _openEditor(tester, const [_rank, _main]);

    final gesture = await _lift(tester, 'm');
    final target = tester.getRect(find.byKey(personalizationCardKey('r')));
    await gesture.moveTo(Offset(target.left + 8, target.center.dy));
    await tester.pump();
    expect(_pairMark('r'), findsOneWidget);
    expect(_pulseTransitions(), findsOneWidget);
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    await gesture.up();
    await tester.pump();

    // A repeating controller left running past the drop keeps the device
    // rendering and hangs every settle in this suite.
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('reduced motion leaves the mark unanimated and present', (
    tester,
  ) async {
    await _openEditor(tester, const [_rank, _main], reducedMotion: true);

    final gesture = await _lift(tester, 'm');
    final target = tester.getRect(find.byKey(personalizationCardKey('r')));
    await gesture.moveTo(Offset(target.left + 8, target.center.dy));
    await tester.pump();

    // The mark is there at full strength and the pulse is not wired at all,
    // rather than wired and hidden.
    expect(_pairMark('r'), findsOneWidget);
    expect(_pulseTransitions(), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);

    await gesture.up();
    await tester.pump();
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

  // The delete affordance stays live while a card is in the air (it is only
  // disabled during a save) and a second finger reaches it, so the layout can
  // change under a held acquisition. Both tests below drive that sequence:
  // hold a landing place, delete the row it was measured against, release.
  testWidgets('a gap that stopped existing under the drag cancels the drop', (
    tester,
  ) async {
    final container = await _openEditor(tester, const [_rank, _main]);
    expect(_working(container), const [FullRow('m'), FullRow('r')]);

    final gesture = await _lift(tester, 'm');
    await gesture.moveTo(
      tester.getCenter(find.byKey(const Key('compositionGap_2'))),
    );
    await tester.pump();
    // The gap below every row — the one the shortened layout will not have.
    expect(_gapMark(2), findsOneWidget);

    // pump, never settle: the landing mark pulses while a card is in the air,
    // and a repeating controller never settles.
    await tester.tap(find.byKey(const Key('compositionDelete_r')));
    await tester.pump();
    expect(_working(container), const [FullRow('m')]);

    await gesture.up();
    await tester.pumpAndSettle();

    // The release lands nowhere rather than inserting past the end of what is
    // left of the layout.
    expect(_working(container), const [FullRow('m')]);
  });

  testWidgets('a pair target deleted under the drag cancels the drop', (
    tester,
  ) async {
    final container = await _openEditor(tester, const [_rank, _main]);

    final gesture = await _lift(tester, 'm');
    final target = tester.getRect(find.byKey(personalizationCardKey('r')));
    await gesture.moveTo(Offset(target.left + 8, target.center.dy));
    await tester.pump();
    // Aimed at the left of the Rank card, which is what a release would pair.
    expect(_pairMark('r'), findsOneWidget);

    await tester.tap(find.byKey(const Key('compositionDelete_r')));
    await tester.pump();
    expect(_working(container), const [FullRow('m')]);

    await gesture.up();
    await tester.pumpAndSettle();

    // The card that was in the air is still placed: pairing beside a target
    // that is gone would lift it out of its row and never put it back.
    expect(_working(container), const [FullRow('m')]);
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
