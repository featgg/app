import 'dart:async';

import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/connections_repository.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/collection_selection.dart';
import 'package:featgg/src/features/profile/domain/composed_card.dart';
import 'package:featgg/src/features/profile/domain/data_menu_selection.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_repository.dart';
import 'package:featgg/src/features/profile/domain/showcase_selection.dart';
import 'package:featgg/src/features/profile/domain/template_catalog.dart';
import 'package:featgg/src/features/profile/presentation/profile_widgets_controller.dart';
import 'package:featgg/src/features/profile/presentation/template_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

const _templateWidget = ProfileWidget(
  id: 'w-1',
  kind: ProfileWidgetKind.template,
  platform: null,
  position: 0,
  isEnabled: true,
  size: ProfileWidgetSize.small,
  templateFill: TemplateFill('my_ranks', <String, String>{}),
);

/// A widgets repository whose `setTemplateFill` records each fill and does not
/// complete until [gate] does — so a write can be held in flight.
final class _GatedWidgetsRepository implements ProfileWidgetsRepository {
  _GatedWidgetsRepository({this.widgets = const []});

  final List<ProfileWidget> widgets;
  final List<TemplateFill> fills = [];

  /// When set, a template write does not complete until this completes.
  Completer<void>? gate;

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets() async =>
      right(widgets);

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchPublicWidgets(
    String userId,
  ) async => right(const []);

  @override
  Future<Either<Failure, Unit>> setTemplateFill(
    String id,
    ProfileWidgetSize size,
    TemplateFill fill,
  ) async {
    fills.add(fill);
    if (gate != null) await gate!.future;
    return right(unit);
  }

  @override
  Future<Either<Failure, ProfileWidget>> addPlatformWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addTemplateWidget({
    required String templateId,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addComposedWidget({
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addShowcaseWidget({
    required Platform platform,
    required ShowcaseSelection selection,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addCollectionWidget({
    required CollectionSelection selection,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addGameCollectorWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addCompletionistWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addArtWidget({
    Platform? source,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addPassportWidget({
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addRankWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ProfileWidget>> addMainWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setCollectionSize(
    String id,
    ProfileWidgetSize size,
    CollectionSelection selection,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setComposedFill(
    String id,
    ProfileWidgetSize size,
    ComposedFill fill,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setDataMenuSelection(
    String id,
    ProfileWidgetSize size,
    DataMenuSelection selection,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> removeWidget(String id) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setSize(
    String id,
    ProfileWidgetSize size,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setShowcaseSize(
    String id,
    ProfileWidgetSize size,
    ShowcaseSelection selection,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> reorder(List<String> orderedIds) async =>
      throw UnimplementedError();
}

final class _FakeConnectionsRepository implements ConnectionsRepository {
  _FakeConnectionsRepository(this.platforms);

  final List<Platform> platforms;

  @override
  Future<Either<Failure, List<Connection>>> fetchMyConnections() async =>
      right([
        for (final p in platforms)
          Connection(
            platform: p,
            status: ConnectionStatus.active,
            createdAt: DateTime.utc(2026, 1, 1),
          ),
      ]);

  @override
  Future<Either<Failure, Unit>> link({
    required Platform platform,
    required Map<String, String> formInput,
  }) async => right(unit);

  @override
  Future<Either<Failure, Unit>> unlink(Platform platform) async => right(unit);

  @override
  Future<Either<Failure, SyncResult>> refresh(Platform platform) async =>
      right(const SyncResult(skipped: false));

  @override
  Future<Either<Failure, RefreshAllResult>> refreshAll() async =>
      right(const RefreshAllResult(outcomes: []));
}

/// Returns a fixed card per platform from the injected map; null for the rest.
/// A platform mapped to a never-completing future keeps its owner card loading.
final class _FakeCardsRepository implements CardsRepository {
  _FakeCardsRepository({this.cards = const {}, this.pending = const {}});

  final Map<Platform, GameCard?> cards;
  final Set<Platform> pending;

  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) {
    if (pending.contains(platform)) {
      return Completer<Either<Failure, GameCard?>>().future;
    }
    return Future.value(right(cards[platform]));
  }

  @override
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  ) async => right(null);
}

GameCard _card({required Platform platform, List<CardStat> stats = const []}) =>
    GameCard(
      schemaVersion: 1,
      platform: platform,
      title: '${platform.name}-card',
      subtitle: null,
      iconImage: null,
      heroImage: null,
      profileUrl: null,
      stats: stats,
      lastUpdated: DateTime.utc(2026, 6, 1),
      data: null,
    );

/// Opens the slot-fill sheet for [_templateWidget]'s first rank slot and
/// observes the controller so it stays alive across the sheet's pop — mirroring
/// the profile screen host that keeps an in-flight save observable.
class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(profileWidgetsControllerProvider);
    final slot = templateCatalog.first.slots.first;
    return Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          key: const Key('open'),
          onPressed: () => showTemplateSlotFill(context, _templateWidget, slot),
          child: const Text('open'),
        ),
      ),
    );
  }
}

Widget _app(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: const MaterialApp(
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: [Locale('en')],
    home: _Host(),
  ),
);

ProviderContainer _container(
  ProfileWidgetsRepository repo, {
  CardsRepository? cardsRepository,
}) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      connectionsRepositoryProvider.overrideWithValue(
        _FakeConnectionsRepository(const [Platform.chess, Platform.gw2]),
      ),
      profileWidgetsRepositoryProvider.overrideWithValue(repo),
      // The fill sheet watches ownerCardProvider per item; default to a
      // repository with no cards so every watch resolves to null.
      cardsRepositoryProvider.overrideWithValue(
        cardsRepository ?? _FakeCardsRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  testWidgets('slot choices are disabled while a save is in flight', (
    tester,
  ) async {
    final repo = _GatedWidgetsRepository(widgets: const [_templateWidget])
      ..gate = Completer<void>();
    await tester.pumpWidget(_app(_container(repo)));
    await tester.pumpAndSettle();

    // Fill the first rank slot; the write is held open by the gate.
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('slotFillItem_chess.rating')));
    await tester
        .pump(); // sheet pops; the gated write keeps the controller loading

    // Reopen the sheet: with a save pending, a different choice is disabled.
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    final tile = tester.widget<ListTile>(
      find.byKey(const Key('slotFillItem_gw2.wvw_rank')),
    );
    expect(tile.onTap, isNull);

    // Tapping the disabled choice is a no-op: still exactly one write recorded.
    await tester.tap(find.byKey(const Key('slotFillItem_gw2.wvw_rank')));
    await tester.pump();
    expect(repo.fills, hasLength(1));

    // Release the first write; the single recorded write carries that slot.
    repo.gate!.complete();
    await tester.pumpAndSettle();
    expect(repo.fills, hasLength(1));
    expect(repo.fills.single.itemIdFor('slot_1'), 'chess.rating');
  });

  testWidgets(
    "marks a pickable item with no current value as 'no data yet' and keeps it tappable",
    (tester) async {
      final repo = _GatedWidgetsRepository(widgets: const [_templateWidget]);
      final cards = _FakeCardsRepository(
        cards: {
          // chess resolves (has the rating stat); gw2 does not (no wvw_rank).
          Platform.chess: _card(
            platform: Platform.chess,
            stats: const [CardStat(key: 'rating', value: 1500)],
          ),
          Platform.gw2: _card(platform: Platform.gw2, stats: const []),
        },
      );
      await tester.pumpWidget(_app(_container(repo, cardsRepository: cards)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      // The unresolved item carries the annotation; the resolved one does not.
      expect(
        find.byKey(const Key('slotFillNoData_gw2.wvw_rank')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('slotFillNoData_chess.rating')),
        findsNothing,
      );
      // The annotated item stays pickable — no current value never disables it.
      final tile = tester.widget<ListTile>(
        find.byKey(const Key('slotFillItem_gw2.wvw_rank')),
      );
      expect(tile.onTap, isNotNull);
    },
  );

  testWidgets('does not mark an item whose card is still loading', (
    tester,
  ) async {
    final repo = _GatedWidgetsRepository(widgets: const [_templateWidget]);
    final cards = _FakeCardsRepository(
      // gw2's card never completes, so its owner card stays loading.
      cards: {
        Platform.chess: _card(
          platform: Platform.chess,
          stats: const [CardStat(key: 'rating', value: 1500)],
        ),
      },
      pending: const {Platform.gw2},
    );
    await tester.pumpWidget(_app(_container(repo, cardsRepository: cards)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open')));
    // Pump without settling so gw2's card stays in its loading state.
    await tester.pump();

    // No "no data yet" annotation while the card is still loading.
    expect(find.byKey(const Key('slotFillNoData_gw2.wvw_rank')), findsNothing);
  });
}
