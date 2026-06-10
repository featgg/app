import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/connections_repository.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/connections/domain/platform_descriptor.dart';
import 'package:featgg/src/features/connections/presentation/connection_actions_controller.dart';
import 'package:featgg/src/features/connections/presentation/connections_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';

// ---------------------------------------------------------------------------
// Helpers shared across cooldown-timer tests
// ---------------------------------------------------------------------------

Widget _connectionScreenWidget(ProviderContainer container) =>
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en')],
        home: ConnectionsScreen(),
      ),
    );

// ---------------------------------------------------------------------------
// Fake repositories
// ---------------------------------------------------------------------------

final class _FakeConnectionsRepository implements ConnectionsRepository {
  _FakeConnectionsRepository({required this.connectionsResult});

  final Either<Failure, List<Connection>> connectionsResult;

  @override
  Future<Either<Failure, List<Connection>>> fetchMyConnections() async =>
      connectionsResult;

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

/// Connections repository whose refresh always returns a 5-second cooldown.
/// Used to seed a real [ConnectionActionsController] into the cooldown state
/// without relying on the stub controller's fixed deadline.
final class _CooldownConnectionsRepository implements ConnectionsRepository {
  _CooldownConnectionsRepository({required this.connectionsResult});

  final Either<Failure, List<Connection>> connectionsResult;

  @override
  Future<Either<Failure, List<Connection>>> fetchMyConnections() async =>
      connectionsResult;

  @override
  Future<Either<Failure, Unit>> link({
    required Platform platform,
    required Map<String, String> formInput,
  }) async => right(unit);

  @override
  Future<Either<Failure, Unit>> unlink(Platform platform) async => right(unit);

  @override
  Future<Either<Failure, SyncResult>> refresh(Platform platform) async =>
      left(const SyncCooldownFailure(retryAfterSeconds: 5));

  @override
  Future<Either<Failure, RefreshAllResult>> refreshAll() async =>
      right(const RefreshAllResult(outcomes: []));
}

final class _FakeCardsRepository implements CardsRepository {
  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) async =>
      right(null);

  @override
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  ) async => right(null);
}

/// Controller stub whose state reports an active cooldown, so the refresh
/// action renders disabled without driving the real timing logic.
final class _CooldownActionsController extends ConnectionActionsController {
  @override
  ConnectionActionsState build(Platform platform) => ConnectionActionsState(
    refreshing: false,
    unlinking: false,
    cooldownUntil: DateTime.now().add(const Duration(minutes: 1)),
  );
}

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

Future<void> _pump(
  WidgetTester tester, {
  required Either<Failure, List<Connection>> connections,
  bool onCooldown = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        connectionsRepositoryProvider.overrideWithValue(
          _FakeConnectionsRepository(connectionsResult: connections),
        ),
        cardsRepositoryProvider.overrideWithValue(_FakeCardsRepository()),
        if (onCooldown)
          connectionActionsControllerProvider(
            Platform.steam,
          ).overrideWith(_CooldownActionsController.new),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en')],
        home: ConnectionsScreen(),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ConnectionsScreen', () {
    testWidgets('shows loading indicator while connections are loading', (
      tester,
    ) async {
      // Pump a widget that never resolves — check loading state.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectionsRepositoryProvider.overrideWithValue(
              _FakeConnectionsRepository(connectionsResult: right([])),
            ),
            cardsRepositoryProvider.overrideWithValue(_FakeCardsRepository()),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [Locale('en')],
            home: ConnectionsScreen(),
          ),
        ),
      );
      // On first pump, provider is loading.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty state when no connections', (tester) async {
      await _pump(tester, connections: right([]));
      await tester.pump(); // let future resolve
      await tester.pump();

      expect(find.byKey(const Key('connectionsEmpty')), findsOneWidget);
    });

    testWidgets('shows error state on Left(NetworkFailure)', (tester) async {
      await _pump(tester, connections: left(const NetworkFailure()));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('asyncRetryButton')), findsOneWidget);
    });

    testWidgets('shows connection tile when a connection exists', (
      tester,
    ) async {
      final conn = Connection(
        platform: Platform.steam,
        status: ConnectionStatus.active,
        createdAt: DateTime(2026),
        lastSyncAt: DateTime(2026, 6),
        remoteId: '12345',
      );
      await _pump(tester, connections: right([conn]));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('connection_steam')), findsOneWidget);
      // Tile renders the brand display name, not the raw enum token.
      final expectedName =
          platformDescriptors[Platform.steam]?.displayName ?? 'steam';
      expect(find.text(expectedName), findsOneWidget);
    });

    testWidgets('shows SteamLinkForm when no Steam connection exists', (
      tester,
    ) async {
      await _pump(tester, connections: right([]));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('linkForm_steam')), findsOneWidget);
      expect(find.byKey(const Key('steamLinkButton')), findsOneWidget);
    });

    testWidgets('shows a Minecraft link form when no Minecraft connection '
        'exists', (tester) async {
      await _pump(tester, connections: right([]));
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const Key('linkForm_minecraftHypixel')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('minecraftLinkButton')), findsOneWidget);
    });

    testWidgets('renders a Minecraft connection tile and its card slot', (
      tester,
    ) async {
      final conn = Connection(
        platform: Platform.minecraftHypixel,
        status: ConnectionStatus.active,
        createdAt: DateTime(2026),
        lastSyncAt: DateTime(2026, 6),
        remoteId: 'TestPlayer',
      );
      await _pump(tester, connections: right([conn]));
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const Key('connection_minecraftHypixel')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('card_minecraftHypixel')), findsOneWidget);
      // A connected platform is not offered its link form again.
      expect(find.byKey(const Key('linkForm_minecraftHypixel')), findsNothing);
    });

    testWidgets('shows a RetroAchievements link form when no RA connection '
        'exists', (tester) async {
      await _pump(tester, connections: right([]));
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const Key('linkForm_retroachievements')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('retroachievementsLinkButton')),
        findsOneWidget,
      );
    });

    testWidgets('renders a RetroAchievements connection tile and its card '
        'slot', (tester) async {
      final conn = Connection(
        platform: Platform.retroachievements,
        status: ConnectionStatus.active,
        createdAt: DateTime(2026),
        lastSyncAt: DateTime(2026, 6),
        remoteId: 'TestUser',
      );
      await _pump(tester, connections: right([conn]));
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const Key('connection_retroachievements')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('card_retroachievements')), findsOneWidget);
      // A connected platform is not offered its link form again.
      expect(find.byKey(const Key('linkForm_retroachievements')), findsNothing);
    });

    testWidgets('refresh button is enabled when not on cooldown', (
      tester,
    ) async {
      final conn = Connection(
        platform: Platform.steam,
        status: ConnectionStatus.active,
        createdAt: DateTime(2026),
      );
      await _pump(tester, connections: right([conn]));
      await tester.pump();
      await tester.pump();

      final refreshBtn = tester.widget<IconButton>(
        find.byKey(const Key('refreshButton_steam')),
      );
      expect(refreshBtn.onPressed, isNotNull);
    });

    testWidgets('refresh button is disabled during cooldown', (tester) async {
      final conn = Connection(
        platform: Platform.steam,
        status: ConnectionStatus.active,
        createdAt: DateTime(2026),
      );
      await _pump(tester, connections: right([conn]), onCooldown: true);
      await tester.pump();
      await tester.pump();

      final refreshBtn = tester.widget<IconButton>(
        find.byKey(const Key('refreshButton_steam')),
      );
      expect(refreshBtn.onPressed, isNull);
      expect(find.byKey(const Key('cooldownHint')), findsOneWidget);
    });

    testWidgets('shows a League of Legends link form when no LoL connection '
        'exists', (tester) async {
      await _pump(tester, connections: right([]));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('linkForm_leagueOfLegends')), findsOneWidget);
      expect(find.byKey(const Key('lolLinkButton')), findsOneWidget);
    });

    testWidgets(
      'renders a Guild Wars 2 connection tile when a gw2 connection exists',
      (tester) async {
        // gw2 now has a registered descriptor; its connection tile must appear.
        // The screen filters on platformDescriptors, so a registered connection
        // is shown and an unregistered one is silently ignored (code path
        // preserved; no enum value is currently unregistered).
        final conn = Connection(
          platform: Platform.gw2,
          status: ConnectionStatus.active,
          createdAt: DateTime(2026),
        );
        await _pump(tester, connections: right([conn]));
        await tester.pump();
        await tester.pump();

        expect(find.byKey(const Key('connection_gw2')), findsOneWidget);
        expect(find.byKey(const Key('refreshButton_gw2')), findsOneWidget);
        // No empty state — one registered connection is visible.
        expect(find.byKey(const Key('connectionsEmpty')), findsNothing);
      },
    );

    testWidgets('shows a Chess link form when no Chess connection exists', (
      tester,
    ) async {
      await _pump(tester, connections: right([]));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('linkForm_chess')), findsOneWidget);
      expect(find.byKey(const Key('chessLinkButton')), findsOneWidget);
    });

    testWidgets('shows a WoW link form when no WoW connection exists', (
      tester,
    ) async {
      await _pump(tester, connections: right([]));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('linkForm_wowRetail')), findsOneWidget);
      expect(find.byKey(const Key('wowLinkButton')), findsOneWidget);
    });

    testWidgets(
      'while on cooldown: countdown affordance present, refresh button disabled',
      (tester) async {
        final conn = Connection(
          platform: Platform.steam,
          status: ConnectionStatus.active,
          createdAt: DateTime(2026),
        );
        await _pump(tester, connections: right([conn]), onCooldown: true);
        await tester.pump();
        await tester.pump();

        // The CooldownCountdown widget (key: cooldownHint) is visible.
        expect(find.byKey(const Key('cooldownHint')), findsOneWidget);
        // The refresh button is disabled while on cooldown.
        final refreshBtn = tester.widget<IconButton>(
          find.byKey(const Key('refreshButton_steam')),
        );
        expect(refreshBtn.onPressed, isNull);
      },
    );

    testWidgets(
      'after the cooldown window elapses the refresh button re-enables',
      (tester) async {
        // Use the real ConnectionActionsController with a repo that returns a
        // 5-second SyncCooldownFailure. Trigger the cooldown on the notifier
        // before rendering the screen so the widget builds in cooldown state.
        final conn = Connection(
          platform: Platform.steam,
          status: ConnectionStatus.active,
          createdAt: DateTime(2026),
        );
        final cooldownRepo = _CooldownConnectionsRepository(
          connectionsResult: right([conn]),
        );
        final container = ProviderContainer(
          overrides: [
            connectionsRepositoryProvider.overrideWithValue(cooldownRepo),
            cardsRepositoryProvider.overrideWithValue(_FakeCardsRepository()),
          ],
        );
        addTearDown(container.dispose);

        // Subscribe so the auto-dispose controller stays alive.
        container.listen(
          connectionActionsControllerProvider(Platform.steam),
          (_, _) {},
        );

        // Trigger the refresh → seeds a 5-second cooldown window.
        await container
            .read(connectionActionsControllerProvider(Platform.steam).notifier)
            .refresh();

        // Verify cooldown is active before rendering.
        expect(
          container
              .read(connectionActionsControllerProvider(Platform.steam))
              .onCooldown,
          isTrue,
        );

        await tester.pumpWidget(_connectionScreenWidget(container));
        await tester.pump();
        await tester.pump();

        // Refresh button is disabled while on cooldown.
        expect(
          tester
              .widget<IconButton>(find.byKey(const Key('refreshButton_steam')))
              .onPressed,
          isNull,
        );

        // The cooldown is conveyed only by the countdown; the redundant
        // SyncCooldownFailure error text is suppressed.
        expect(find.byKey(const Key('cooldownHint')), findsOneWidget);
        expect(find.byKey(const Key('actionsError')), findsNothing);

        // Advance past the 5-second window; the controller's Timer fires and
        // clears cooldownUntil.
        await tester.pump(const Duration(seconds: 6));

        // Refresh button re-enables.
        expect(
          tester
              .widget<IconButton>(find.byKey(const Key('refreshButton_steam')))
              .onPressed,
          isNotNull,
        );
      },
    );
  });
}
