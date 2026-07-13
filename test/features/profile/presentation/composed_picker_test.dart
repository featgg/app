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
import 'package:featgg/src/features/profile/presentation/composed_picker.dart';
import 'package:featgg/src/features/profile/presentation/profile_widgets_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

const _composedWidget = ProfileWidget(
  id: 'w-1',
  kind: ProfileWidgetKind.composed,
  platform: null,
  position: 0,
  isEnabled: true,
  size: ProfileWidgetSize.small,
  composedFill: ComposedFill(<String>[]),
);

/// A widgets repository whose `setComposedFill` records each fill and does not
/// complete until [gate] does — so a write can be held in flight.
final class _GatedWidgetsRepository implements ProfileWidgetsRepository {
  _GatedWidgetsRepository({this.widgets = const []});

  final List<ProfileWidget> widgets;
  final List<ComposedFill> fills = [];

  /// When set, a composed write does not complete until this completes.
  Completer<void>? gate;

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets() async =>
      right(widgets);

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchPublicWidgets(
    String userId,
  ) async => right(const []);

  @override
  Future<Either<Failure, Unit>> setComposedFill(
    String id,
    ProfileWidgetSize size,
    ComposedFill fill,
  ) async {
    fills.add(fill);
    if (gate != null) await gate!.future;
    return right(unit);
  }

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
  Future<Either<Failure, ProfileWidget>> addPassportWidget({
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
  Future<Either<Failure, Unit>> setTemplateFill(
    String id,
    ProfileWidgetSize size,
    TemplateFill fill,
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
/// A platform mapped to pending keeps its owner card loading.
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

/// Opens the composed-item picker and observes the controller so it stays alive
/// across the sheet — mirroring the profile screen host that keeps an in-flight
/// save observable.
class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(profileWidgetsControllerProvider);
    return Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          key: const Key('open'),
          onPressed: () => showComposedItemPicker(context, _composedWidget),
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
  List<Platform> connected = const [Platform.chess, Platform.gw2],
}) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      connectionsRepositoryProvider.overrideWithValue(
        _FakeConnectionsRepository(connected),
      ),
      profileWidgetsRepositoryProvider.overrideWithValue(repo),
      cardsRepositoryProvider.overrideWithValue(
        cardsRepository ?? _FakeCardsRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  testWidgets(
    'item choices are disabled while a save is in flight; a rapid second pick records one write',
    (tester) async {
      final repo = _GatedWidgetsRepository(widgets: const [_composedWidget])
        ..gate = Completer<void>();
      await tester.pumpWidget(_app(_container(repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      // Toggle the first item on; the write is held open by the gate.
      await tester.tap(find.byKey(const Key('composedItem_chess.rating')));
      await tester.pump();

      // With a save pending, a different choice is disabled.
      final tile = tester.widget<SwitchListTile>(
        find.byKey(const Key('composedItem_gw2.wvw_rank')),
      );
      expect(tile.onChanged, isNull);

      // Tapping the disabled choice is a no-op: still exactly one write.
      await tester.tap(find.byKey(const Key('composedItem_gw2.wvw_rank')));
      await tester.pump();
      expect(repo.fills, hasLength(1));

      // Release the first write; the single recorded write carries that item.
      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(repo.fills, hasLength(1));
      expect(repo.fills.single.contains('chess.rating'), isTrue);
    },
  );

  testWidgets(
    "marks a pickable item with no current value as 'no data yet' and keeps it tappable",
    (tester) async {
      final repo = _GatedWidgetsRepository(widgets: const [_composedWidget]);
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
        find.byKey(const Key('composedNoData_gw2.wvw_rank')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('composedNoData_chess.rating')),
        findsNothing,
      );
      // The annotated item stays pickable — no current value never disables it.
      final tile = tester.widget<SwitchListTile>(
        find.byKey(const Key('composedItem_gw2.wvw_rank')),
      );
      expect(tile.onChanged, isNotNull);
    },
  );

  testWidgets('does not mark an item whose card is still loading', (
    tester,
  ) async {
    final repo = _GatedWidgetsRepository(widgets: const [_composedWidget]);
    final cards = _FakeCardsRepository(
      cards: {
        Platform.chess: _card(
          platform: Platform.chess,
          stats: const [CardStat(key: 'rating', value: 1500)],
        ),
      },
      // gw2's card never completes, so its owner card stays loading.
      pending: const {Platform.gw2},
    );
    await tester.pumpWidget(_app(_container(repo, cardsRepository: cards)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open')));
    // Pump without settling so gw2's card stays in its loading state.
    await tester.pump();

    expect(find.byKey(const Key('composedNoData_gw2.wvw_rank')), findsNothing);
  });

  testWidgets('toggling an item records the picked id via setComposedFill', (
    tester,
  ) async {
    final repo = _GatedWidgetsRepository(widgets: const [_composedWidget]);
    await tester.pumpWidget(_app(_container(repo)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('composedItem_chess.rating')));
    await tester.pumpAndSettle();

    expect(repo.fills, hasLength(1));
    expect(repo.fills.single.itemIds, ['chess.rating']);
  });

  testWidgets('toggling flips the switch immediately, without reopening', (
    tester,
  ) async {
    final repo = _GatedWidgetsRepository(widgets: const [_composedWidget]);
    await tester.pumpWidget(_app(_container(repo)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    SwitchListTile tile() => tester.widget<SwitchListTile>(
      find.byKey(const Key('composedItem_chess.rating')),
    );
    expect(tile().value, isFalse);

    await tester.tap(find.byKey(const Key('composedItem_chess.rating')));
    await tester.pumpAndSettle();

    // The optimistic edit buffer flips the switch in place — the sheet is never
    // reopened, so the value cannot be coming from the captured widget snapshot.
    expect(tile().value, isTrue);
  });

  testWidgets('does not offer showcase items (no composed render path yet)', (
    tester,
  ) async {
    final repo = _GatedWidgetsRepository(widgets: const [_composedWidget]);
    await tester.pumpWidget(
      _app(_container(repo, connected: const [Platform.steam])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    // A scalar steam stat is offered; the showcase pointer is filtered out
    // because resolveSlot would always omit it on the card.
    expect(
      find.byKey(const Key('composedItem_steam.hours_played')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('composedItem_steam.library_showcase')),
      findsNothing,
    );
  });
}
