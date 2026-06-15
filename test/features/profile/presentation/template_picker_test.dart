import 'dart:async';

import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/connections_repository.dart';
import 'package:featgg/src/features/profile/domain/data_menu_selection.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_repository.dart';
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

ProviderContainer _container(ProfileWidgetsRepository repo) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      connectionsRepositoryProvider.overrideWithValue(
        _FakeConnectionsRepository(const [Platform.chess, Platform.gw2]),
      ),
      profileWidgetsRepositoryProvider.overrideWithValue(repo),
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
}
