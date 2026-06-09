import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../domain/connection.dart';
import '../domain/connections_providers.dart';
import 'connections_provider.dart';

part 'connection_actions_controller.g.dart';

/// Fallback client-side cooldown used when a SYNC_COOLDOWN response carries
/// no usable `retry_after` in the body. Response headers are discarded by the
/// SDK (FunctionException exposes only status, details, and reasonPhrase), so
/// the header-only `Retry-After` on `sync-<platform>` is unreachable. When the
/// body carries `retry_after`, that value is used instead (via
/// `SyncCooldownFailure.retryAfterSeconds`); this constant is the fallback.
const Duration _syncCooldownFallback = Duration(seconds: 60);

/// Immutable state for the connection-actions controller.
final class ConnectionActionsState extends Equatable {
  const ConnectionActionsState({
    required this.refreshing,
    required this.unlinking,
    this.failure,
    this.refreshSkipped = false,
    this.unlinked = false,
    this.cooldownUntil,
  });

  factory ConnectionActionsState.initial() =>
      const ConnectionActionsState(refreshing: false, unlinking: false);

  /// True while a refresh call is in flight.
  final bool refreshing;

  /// True while an unlink call is in flight.
  final bool unlinking;

  /// Last failure from any action, or null.
  final Failure? failure;

  /// True when the last refresh returned skipped: true.
  final bool refreshSkipped;

  /// True once an unlink succeeded.
  final bool unlinked;

  /// When non-null and in the future, the refresh action is disabled.
  final DateTime? cooldownUntil;

  /// Whether the refresh action is currently on cooldown.
  bool get onCooldown =>
      cooldownUntil != null && DateTime.now().isBefore(cooldownUntil!);

  ConnectionActionsState copyWith({
    bool? refreshing,
    bool? unlinking,
    Failure? failure,
    bool? refreshSkipped,
    bool? unlinked,
    DateTime? cooldownUntil,
    bool clearFailure = false,
    bool clearCooldown = false,
  }) => ConnectionActionsState(
    refreshing: refreshing ?? this.refreshing,
    unlinking: unlinking ?? this.unlinking,
    failure: clearFailure ? null : (failure ?? this.failure),
    refreshSkipped: refreshSkipped ?? this.refreshSkipped,
    unlinked: unlinked ?? this.unlinked,
    cooldownUntil: clearCooldown ? null : (cooldownUntil ?? this.cooldownUntil),
  );

  @override
  List<Object?> get props => [
    refreshing,
    unlinking,
    failure,
    refreshSkipped,
    unlinked,
    cooldownUntil,
  ];
}

@riverpod
class ConnectionActionsController extends _$ConnectionActionsController {
  Timer? _cooldownTimer;

  @override
  ConnectionActionsState build(Platform platform) {
    ref.onDispose(() => _cooldownTimer?.cancel());
    return ConnectionActionsState.initial();
  }

  void _scheduleCooldownTimer(Duration duration) {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(duration, () {
      if (ref.mounted) {
        state = state.copyWith(clearCooldown: true);
      }
    });
  }

  /// Triggers a sync for the family [platform]. Short-circuits if the
  /// client-side cooldown is still active. On success, invalidates the
  /// connections and card reads. On [SyncCooldownFailure], sets a fixed
  /// cooldown-until timestamp.
  Future<void> refresh() async {
    if (state.onCooldown) return;

    state = state.copyWith(
      refreshing: true,
      clearFailure: true,
      refreshSkipped: false,
    );

    final repo = ref.read(connectionsRepositoryProvider);
    final result = await repo.refresh(platform);

    if (!ref.mounted) return;

    result.fold(
      (failure) {
        if (failure is SyncCooldownFailure) {
          final cooldown = failure.retryAfterSeconds != null
              ? Duration(seconds: failure.retryAfterSeconds!)
              : _syncCooldownFallback;
          state = state.copyWith(
            refreshing: false,
            failure: failure,
            cooldownUntil: DateTime.now().add(cooldown),
          );
          _scheduleCooldownTimer(cooldown);
        } else {
          state = state.copyWith(refreshing: false, failure: failure);
        }
      },
      (syncResult) {
        ref.invalidate(myConnectionsProvider);
        ref.invalidate(cardProvider(platform));
        state = state.copyWith(
          refreshing: false,
          refreshSkipped: syncResult.skipped,
          clearFailure: true,
        );
      },
    );
  }

  /// Unlinks the family [platform]. On success, invalidates the connections
  /// read.
  Future<void> unlink() async {
    state = state.copyWith(unlinking: true, clearFailure: true);

    final repo = ref.read(connectionsRepositoryProvider);
    final result = await repo.unlink(platform);

    if (!ref.mounted) return;

    result.fold(
      (failure) {
        state = state.copyWith(unlinking: false, failure: failure);
      },
      (_) {
        ref.invalidate(myConnectionsProvider);
        ref.invalidate(cardProvider(platform));
        state = state.copyWith(
          unlinking: false,
          unlinked: true,
          clearFailure: true,
        );
      },
    );
  }
}
