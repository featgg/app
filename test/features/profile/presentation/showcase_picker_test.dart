import 'dart:async';

import 'package:featgg/src/core/core.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/composed_card.dart';
import 'package:featgg/src/features/profile/domain/data_menu_selection.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_repository.dart';
import 'package:featgg/src/features/profile/domain/showcase_selection.dart';
import 'package:featgg/src/features/profile/domain/template_catalog.dart';
import 'package:featgg/src/features/profile/presentation/showcase_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Records the add-showcase call so the tile-tap write contract is provable,
/// and returns `[]` for the read the controller re-fetches after a successful
/// add. Every other mutation is unreachable in these tests.
final class _RecordingWidgetsRepository implements ProfileWidgetsRepository {
  Platform? lastPlatform;
  ShowcaseSelection? lastSelection;
  int? lastPosition;
  ProfileWidgetSize? lastSize;

  @override
  Future<Either<Failure, ProfileWidget>> addShowcaseWidget({
    required Platform platform,
    required ShowcaseSelection selection,
    required int position,
    required ProfileWidgetSize size,
  }) async {
    lastPlatform = platform;
    lastSelection = selection;
    lastPosition = position;
    lastSize = size;
    return right(
      ProfileWidget(
        id: 'new',
        kind: ProfileWidgetKind.showcase,
        platform: platform,
        position: position,
        isEnabled: true,
        size: size,
        showcaseSelection: selection,
      ),
    );
  }

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets() async =>
      right(const []);

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchPublicWidgets(
    String userId,
  ) async => right(const []);

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
  Future<Either<Failure, Unit>> setTemplateFill(
    String id,
    ProfileWidgetSize size,
    TemplateFill fill,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> setComposedFill(
    String id,
    ProfileWidgetSize size,
    ComposedFill fill,
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
  Future<Either<Failure, Unit>> setDataMenuSelection(
    String id,
    ProfileWidgetSize size,
    DataMenuSelection selection,
  ) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> reorder(List<String> orderedIds) async =>
      throw UnimplementedError();
}

/// Returns a fixed card for any platform (the picker only reads Steam).
final class _FakeCardsRepository implements CardsRepository {
  _FakeCardsRepository(this._card);

  final GameCard? _card;

  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) async =>
      right(_card);

  @override
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  ) async => right(null);
}

/// Holds the card future open so the picker's loading branch is observable.
final class _PendingCardsRepository implements CardsRepository {
  final _completer = Completer<Either<Failure, GameCard?>>();

  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) =>
      _completer.future;

  @override
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  ) async => right(null);
}

LibraryShowcaseEntry _entry(int appId) =>
    LibraryShowcaseEntry(appId: appId, title: 'Game $appId', hours: 100);

/// A Steam card carrying [library] (art-less so no real image decodes in tests).
GameCard _steamCard(List<LibraryShowcaseEntry> library) => GameCard(
  schemaVersion: 1,
  platform: Platform.steam,
  title: 'Steam',
  subtitle: null,
  iconImage: null,
  heroImage: null,
  profileUrl: null,
  stats: const [],
  lastUpdated: DateTime.utc(2026, 6, 1),
  data: SteamCardData(libraryShowcase: library, recentGames: const []),
);

ProfileWidget _showcaseFor(int appId, {required int position}) => ProfileWidget(
  id: 'w-$appId',
  kind: ProfileWidgetKind.showcase,
  platform: Platform.steam,
  position: position,
  isEnabled: true,
  size: ProfileWidgetSize.small,
  showcaseSelection: ShowcaseSelection(gameRef: appId.toString()),
);

ProfileWidget _platformWidget({required int position}) => ProfileWidget(
  id: 'plat-$position',
  kind: ProfileWidgetKind.platform,
  platform: Platform.steam,
  position: position,
  isEnabled: true,
  size: ProfileWidgetSize.small,
);

Widget _harness({
  required CardsRepository cardsRepo,
  required ProfileWidgetsRepository widgetsRepo,
  required List<ProfileWidget> existing,
}) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      cardsRepositoryProvider.overrideWithValue(cardsRepo),
      profileWidgetsRepositoryProvider.overrideWithValue(widgetsRepo),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('openPicker'),
            onPressed: () => showShowcasePicker(context, existing: existing),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('offers a tile per addable Steam library game, excluding '
      'already-showcased', (tester) async {
    // Library [730, 570]; 730 is already showcased, so only 570 is addable.
    await tester.pumpWidget(
      _harness(
        cardsRepo: _FakeCardsRepository(_steamCard([_entry(730), _entry(570)])),
        widgetsRepo: _RecordingWidgetsRepository(),
        existing: [_showcaseFor(730, position: 0)],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('openPicker')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('showcasePickerTile_570')), findsOneWidget);
    expect(find.byKey(const Key('showcasePickerTile_730')), findsNothing);
  });

  testWidgets('empty library shows the localized empty state', (tester) async {
    await tester.pumpWidget(
      _harness(
        cardsRepo: _FakeCardsRepository(_steamCard(const [])),
        widgetsRepo: _RecordingWidgetsRepository(),
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('openPicker')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('showcasePickerEmpty')), findsOneWidget);
    expect(find.byKey(const Key('showcasePickerAllAdded')), findsNothing);
  });

  testWidgets('all games already showcased shows the all-added state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        cardsRepo: _FakeCardsRepository(_steamCard([_entry(730)])),
        widgetsRepo: _RecordingWidgetsRepository(),
        existing: [_showcaseFor(730, position: 0)],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('openPicker')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('showcasePickerAllAdded')), findsOneWidget);
    expect(find.byKey(const Key('showcasePickerEmpty')), findsNothing);
  });

  testWidgets('tapping a tile adds a showcase for that game and closes', (
    tester,
  ) async {
    // An existing platform widget at position 2 (not a showcase, so it does not
    // shrink the addable set) proves the insert position is max+1 = 3.
    final widgetsRepo = _RecordingWidgetsRepository();
    await tester.pumpWidget(
      _harness(
        cardsRepo: _FakeCardsRepository(_steamCard([_entry(570)])),
        widgetsRepo: widgetsRepo,
        existing: [_platformWidget(position: 2)],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('openPicker')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('showcasePickerTile_570')));
    await tester.pumpAndSettle();

    // The write carries Steam, the tapped game ref, the small default size, and
    // the max+1 position.
    expect(widgetsRepo.lastPlatform, Platform.steam);
    expect(widgetsRepo.lastSelection, const ShowcaseSelection(gameRef: '570'));
    expect(widgetsRepo.lastSize, ProfileWidgetSize.small);
    expect(widgetsRepo.lastPosition, 3);

    // The sheet closed on tap.
    expect(find.byKey(const Key('showcasePickerTile_570')), findsNothing);
  });

  testWidgets('Steam card loading shows the loader', (tester) async {
    await tester.pumpWidget(
      _harness(
        cardsRepo: _PendingCardsRepository(),
        widgetsRepo: _RecordingWidgetsRepository(),
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('openPicker')));
    // Let the sheet animate in while the card future stays pending; the picker
    // renders the centralized loader, not tiles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('showcasePickerEmpty')), findsNothing);
  });
}
