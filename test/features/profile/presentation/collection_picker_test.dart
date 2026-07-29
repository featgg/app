import 'package:featgg/src/core/core.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/connections_repository.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/collection_selection.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_repository.dart';
import 'package:featgg/src/features/profile/domain/showcase_selection.dart';
import 'package:featgg/src/features/profile/presentation/showcase_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Records the add-collection call so the confirm write contract is provable,
/// and returns `[]` for the read the controller re-fetches after a successful
/// add. Every other mutation is unreachable in these tests.
final class _RecordingWidgetsRepository implements ProfileWidgetsRepository {
  CollectionSelection? lastCollectionSelection;
  int? lastCollectionPosition;
  ProfileWidgetSize? lastCollectionSize;

  @override
  Future<Either<Failure, ProfileWidget>> addCollectionWidget({
    required CollectionSelection selection,
    required int position,
    required ProfileWidgetSize size,
  }) async {
    lastCollectionSelection = selection;
    lastCollectionPosition = position;
    lastCollectionSize = size;
    return right(
      ProfileWidget(
        id: 'new',
        kind: ProfileWidgetKind.collection,
        platform: null,
        position: position,
        isEnabled: true,
        size: size,
        collectionSelection: selection,
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
  Future<Either<Failure, ProfileWidget>> addShowcaseWidget({
    required Platform platform,
    required ShowcaseSelection selection,
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

/// A connections repo reporting Steam linked, so the catalog renders the
/// Steam-derived Collection group whose curated row opens this picker.
final class _FakeConnectionsRepository implements ConnectionsRepository {
  @override
  Future<Either<Failure, List<Connection>>> fetchMyConnections() async =>
      right([
        Connection(
          platform: Platform.steam,
          status: ConnectionStatus.active,
          createdAt: DateTime.utc(2024),
        ),
      ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// A Steam card whose library holds [count] art-less entries (app ids 1..count).
GameCard _steamCard(int count) => GameCard(
  schemaVersion: 1,
  platform: Platform.steam,
  title: 'Steam',
  subtitle: null,
  iconImage: null,
  heroImage: null,
  profileUrl: null,
  stats: const [],
  lastUpdated: DateTime.utc(2026, 6, 1),
  data: SteamCardData(
    libraryShowcase: [
      for (var i = 1; i <= count; i++)
        LibraryShowcaseEntry(appId: i, title: 'Game $i', hours: 100),
    ],
    recentGames: const [],
  ),
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
      connectionsRepositoryProvider.overrideWithValue(
        _FakeConnectionsRepository(),
      ),
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

bool _addEnabled(WidgetTester tester) =>
    tester
        .widget<FilledButton>(
          find.byKey(const Key('collectionPickerAddButton')),
        )
        .onPressed !=
    null;

Future<void> _openCollectionMode(
  WidgetTester tester,
  AppLocalizations l10n,
) async {
  await tester.tap(find.byKey(const Key('openPicker')));
  await tester.pumpAndSettle();
  // Reach the curated-Collection picker through its catalog step row.
  await tester.ensureVisible(find.byKey(const Key('collectionCuratedRow')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('collectionCuratedRow')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the mode toggle is present and Collection mode is catalog-only '
      '(no TextField)', (tester) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _harness(
        cardsRepo: _FakeCardsRepository(_steamCard(6)),
        widgetsRepo: _RecordingWidgetsRepository(),
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _openCollectionMode(tester, l10n);

    expect(find.byKey(const Key('collectionPickerTitle')), findsOneWidget);
    // Catalog-only: no free-text entry anywhere in the collection body.
    expect(find.byType(TextField), findsNothing);
    // The catalog title chips are present.
    expect(
      find.byKey(const Key('collectionTitleChip_collectionTitleFavorites')),
      findsOneWidget,
    );
  });

  testWidgets('Add is disabled below 2, requires a title, and enables at 2–5', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _harness(
        cardsRepo: _FakeCardsRepository(_steamCard(6)),
        widgetsRepo: _RecordingWidgetsRepository(),
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _openCollectionMode(tester, l10n);

    // Nothing selected → disabled.
    expect(_addEnabled(tester), isFalse);

    // One game + a title is still below the minimum → disabled.
    await tester.tap(find.byKey(const Key('collectionPickerTile_1')));
    await tester.tap(
      find.byKey(const Key('collectionTitleChip_collectionTitleFavorites')),
    );
    await tester.pumpAndSettle();
    expect(_addEnabled(tester), isFalse);

    // A second game meets the minimum → enabled.
    await tester.tap(find.byKey(const Key('collectionPickerTile_2')));
    await tester.pumpAndSettle();
    expect(_addEnabled(tester), isTrue);
  });

  testWidgets('three games without a title keep Add disabled', (tester) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _harness(
        cardsRepo: _FakeCardsRepository(_steamCard(6)),
        widgetsRepo: _RecordingWidgetsRepository(),
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _openCollectionMode(tester, l10n);

    await tester.tap(find.byKey(const Key('collectionPickerTile_1')));
    await tester.tap(find.byKey(const Key('collectionPickerTile_2')));
    await tester.tap(find.byKey(const Key('collectionPickerTile_3')));
    await tester.pumpAndSettle();

    // Three games but no title chosen → still disabled.
    expect(_addEnabled(tester), isFalse);
  });

  testWidgets('a tap on an unselected tile at the cap (5) is ignored', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _harness(
        cardsRepo: _FakeCardsRepository(_steamCard(6)),
        widgetsRepo: _RecordingWidgetsRepository(),
        existing: const [],
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _openCollectionMode(tester, l10n);

    for (final id in [1, 2, 3, 4, 5]) {
      await tester.tap(find.byKey(Key('collectionPickerTile_$id')));
    }
    await tester.pumpAndSettle();

    // Five tiles carry the selected-check overlay.
    for (final id in [1, 2, 3, 4, 5]) {
      expect(find.byKey(Key('collectionTileCheck_$id')), findsOneWidget);
    }

    // Tapping a sixth unselected tile is a no-op at the cap: it gains no check.
    await tester.tap(find.byKey(const Key('collectionPickerTile_6')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('collectionTileCheck_6')), findsNothing);
  });

  testWidgets('confirm calls addCollection with the selected refs, chosen '
      'title, wide size, and max+1 position', (tester) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final widgetsRepo = _RecordingWidgetsRepository();
    await tester.pumpWidget(
      _harness(
        cardsRepo: _FakeCardsRepository(_steamCard(6)),
        widgetsRepo: widgetsRepo,
        // An existing widget at position 2 proves the insert position is max+1.
        existing: [_platformWidget(position: 2)],
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _openCollectionMode(tester, l10n);

    await tester.tap(find.byKey(const Key('collectionPickerTile_1')));
    await tester.tap(find.byKey(const Key('collectionPickerTile_2')));
    await tester.tap(find.byKey(const Key('collectionPickerTile_3')));
    await tester.tap(
      find.byKey(const Key('collectionTitleChip_collectionTitleBacklog')),
    );
    await tester.pumpAndSettle();

    // The confirm button scrolls with the shared sheet surface, so bring it into
    // view before tapping.
    await tester.ensureVisible(
      find.byKey(const Key('collectionPickerAddButton')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('collectionPickerAddButton')));
    await tester.pumpAndSettle();

    expect(widgetsRepo.lastCollectionSelection?.gameRefs, ['1', '2', '3']);
    expect(
      widgetsRepo.lastCollectionSelection?.titleKey,
      'collectionTitleBacklog',
    );
    expect(widgetsRepo.lastCollectionSize, ProfileWidgetSize.wide);
    expect(widgetsRepo.lastCollectionPosition, 3);

    // The sheet closed on confirm.
    expect(find.byKey(const Key('collectionPickerAddButton')), findsNothing);
  });
}
