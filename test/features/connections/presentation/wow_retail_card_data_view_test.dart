import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/core/widgets/cooldown_countdown.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/connections_repository.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/connections/presentation/connection_actions_controller.dart';
import 'package:featgg/src/features/connections/presentation/wow_retail_card_data_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

// ---------------------------------------------------------------------------
// Fake
// ---------------------------------------------------------------------------

final class _FakeConnectionsRepository implements ConnectionsRepository {
  @override
  Future<Either<Failure, List<Connection>>> fetchMyConnections() async =>
      right([]);

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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(Widget child) {
  final container = ProviderContainer(
    overrides: [
      connectionsRepositoryProvider.overrideWithValue(
        _FakeConnectionsRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

const _profile = WowProfile(
  race: 'Orc',
  faction: 'HORDE',
  className: 'Shaman',
  spec: 'Enhancement',
  level: 70,
  ilvlAvg: 492,
  ilvlEquipped: 489,
);

final _run = WowMythicRun(
  keystoneLevel: 20,
  dungeonName: 'Dawn of the Infinite',
  completedTimestamp: DateTime.fromMillisecondsSinceEpoch(
    1717200000000,
    isUtc: true,
  ),
  durationMs: 1920000,
  isCompletedWithinTime: true,
  rating: 245.5,
);

final _achievement = WowRecentAchievement(
  id: 12345,
  name: 'Keystone Master',
  completedAt: DateTime.utc(2026, 5, 1),
);

const _freshData = WowRetailCardData(
  profile: _profile,
  mythicPlus: WowMythicPlus(rating: 2450.5, bestRuns: []),
  recentAchievements: [],
  attribution: 'Data provided by Blizzard',
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('WowRetailCardDataView', () {
    // -------------------------------------------------------------------------
    // Fresh cases (isStale: false)
    // -------------------------------------------------------------------------

    testWidgets('fresh + owner: renders profile rows and attribution', (
      tester,
    ) async {
      final data = WowRetailCardData(
        profile: _profile,
        mythicPlus: WowMythicPlus(rating: 2450.5, bestRuns: [_run]),
        recentAchievements: [_achievement],
        attribution: 'Data provided by Blizzard',
      );

      await tester.pumpWidget(
        _wrap(WowRetailCardDataView(data: data, isOwner: true, isStale: false)),
      );
      await tester.pump();

      expect(find.byKey(const Key('wowItemLevelLabel')), findsOneWidget);
      expect(find.byKey(const Key('wowClassLabel')), findsOneWidget);
      expect(find.byKey(const Key('wowSpecLabel')), findsOneWidget);
      expect(find.byKey(const Key('wowFactionLabel')), findsOneWidget);
      expect(find.byKey(const Key('wowLevelLabel')), findsOneWidget);
      expect(find.byKey(const Key('wowBestRun_0')), findsOneWidget);
      expect(find.byKey(const Key('wowAttribution')), findsOneWidget);
      expect(
        find.byKey(const Key('wowRecentAchievementsHeading')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('wowStaleState')), findsNothing);
    });

    testWidgets('fresh + non-owner: renders profile rows and attribution', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          WowRetailCardDataView(
            data: _freshData,
            isOwner: false,
            isStale: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('wowItemLevelLabel')), findsOneWidget);
      expect(find.byKey(const Key('wowAttribution')), findsOneWidget);
      expect(find.byKey(const Key('wowStaleState')), findsNothing);
    });

    testWidgets('absent M+ omits the M+ section', (tester) async {
      const noMpData = WowRetailCardData(
        profile: _profile,
        recentAchievements: [],
        attribution: 'Data provided by Blizzard',
      );

      await tester.pumpWidget(
        _wrap(
          WowRetailCardDataView(data: noMpData, isOwner: true, isStale: false),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('wowItemLevelLabel')), findsOneWidget);
      expect(find.byKey(const Key('wowMythicRatingHeading')), findsNothing);
      expect(find.byKey(const Key('wowBestRunsHeading')), findsNothing);
      expect(find.byKey(const Key('wowBestRun_0')), findsNothing);
      expect(find.byKey(const Key('wowAttribution')), findsOneWidget);
      expect(find.byKey(const Key('wowStaleState')), findsNothing);
    });

    testWidgets(
      'present M+ block with no rating and no runs omits the section',
      (tester) async {
        const emptyMpData = WowRetailCardData(
          profile: _profile,
          mythicPlus: WowMythicPlus(rating: null, bestRuns: []),
          recentAchievements: [],
          attribution: 'Data provided by Blizzard',
        );

        await tester.pumpWidget(
          _wrap(
            WowRetailCardDataView(
              data: emptyMpData,
              isOwner: true,
              isStale: false,
            ),
          ),
        );
        await tester.pump();

        expect(find.byKey(const Key('wowItemLevelLabel')), findsOneWidget);
        expect(find.byKey(const Key('wowMythicRatingHeading')), findsNothing);
        expect(find.byKey(const Key('wowBestRunsHeading')), findsNothing);
        expect(find.byKey(const Key('wowAttribution')), findsOneWidget);
      },
    );

    // -------------------------------------------------------------------------
    // Stale cases
    // -------------------------------------------------------------------------

    testWidgets(
      'owner + stale: shows wowStaleState, hides data rows, shows attribution',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            WowRetailCardDataView(
              data: _freshData,
              isOwner: true,
              isStale: true,
            ),
          ),
        );
        await tester.pump();

        expect(find.byKey(const Key('wowStaleState')), findsOneWidget);
        expect(find.byKey(const Key('wowItemLevelLabel')), findsNothing);
        expect(find.byKey(const Key('wowClassLabel')), findsNothing);
        // Attribution still shows for the owner in stale state.
        expect(find.byKey(const Key('wowAttribution')), findsOneWidget);
      },
    );

    testWidgets('non-owner + stale: renders nothing (SizedBox.shrink)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          WowRetailCardDataView(
            data: _freshData,
            isOwner: false,
            isStale: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('wowStaleState')), findsNothing);
      expect(find.byKey(const Key('wowItemLevelLabel')), findsNothing);
      expect(find.byKey(const Key('wowAttribution')), findsNothing);
    });

    // -------------------------------------------------------------------------
    // Controller interaction: owner stale affordance reads onCooldown
    // -------------------------------------------------------------------------

    testWidgets(
      'owner + stale + not on cooldown: wowStaleState tap is not disabled',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            WowRetailCardDataView(
              data: _freshData,
              isOwner: true,
              isStale: true,
            ),
          ),
        );
        await tester.pump();

        // The stale affordance widget exists and is tappable (no crash on tap).
        expect(find.byKey(const Key('wowStaleState')), findsOneWidget);
        await tester.tap(find.byKey(const Key('wowStaleState')));
        await tester.pump();
      },
    );

    testWidgets('owner + stale + on cooldown: CooldownCountdown is rendered', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          connectionsRepositoryProvider.overrideWithValue(
            _FakeConnectionsRepository(),
          ),
          connectionActionsControllerProvider(
            Platform.wowRetail,
          ).overrideWith(() => _CooldownActionsController()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: SingleChildScrollView(
                child: WowRetailCardDataView(
                  data: _freshData,
                  isOwner: true,
                  isStale: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // CooldownCountdown should be present when on cooldown.
      expect(find.byType(CooldownCountdown), findsOneWidget);
    });
  });
}

/// Stub controller that always reports an active cooldown.
final class _CooldownActionsController extends ConnectionActionsController {
  @override
  ConnectionActionsState build(Platform platform) => ConnectionActionsState(
    refreshing: false,
    unlinking: false,
    cooldownUntil: DateTime.now().add(const Duration(minutes: 1)),
  );
}
