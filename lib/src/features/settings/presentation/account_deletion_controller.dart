import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../domain/account_deletion.dart';
import '../domain/settings_providers.dart';

part 'account_deletion_controller.g.dart';

/// Short client-side debounce on the OTP actions. Engaged after a successful
/// request/resend send and after a `429 OTP_RATE_LIMIT` on any deletion action,
/// so the request/resend and confirm buttons back off for the window instead of
/// re-enabling immediately and letting the user hammer the throttled endpoint.
/// Anti-spam UX only — the server's limit is authoritative; the window is fixed
/// and short rather than mirrored from the server because the backend documents
/// no fixed retry interval the client could reproduce.
const _requestCooldown = Duration(seconds: 60);

/// Step of the account-deletion flow the screen is currently rendering.
enum DeletionStep {
  /// Entry state: the user has not yet requested a code.
  idle,

  /// A code has been sent; the user is entering it.
  awaitingCode,

  /// The code was accepted; deletion is scheduled. Shows the target date.
  scheduled,

  /// A scheduled deletion was cancelled during the grace period.
  cancelled,
}

/// Immutable controller state for the account-deletion flow.
final class AccountDeletionState extends Equatable {
  const AccountDeletionState({
    required this.step,
    required this.submitting,
    required this.requestCooldownActive,
    required this.requestCooldownSeconds,
    required this.requestCooldownTick,
    this.scheduledAt,
    this.failure,
  });

  factory AccountDeletionState.initial() => const AccountDeletionState(
    step: DeletionStep.idle,
    submitting: false,
    requestCooldownActive: false,
    requestCooldownSeconds: 0,
    requestCooldownTick: 0,
  );

  final DeletionStep step;

  /// True while a request/confirm call is in flight; the action button is
  /// disabled and shows a spinner.
  final bool submitting;

  /// True while the post-send client debounce is active. Disables the
  /// request/resend button until the window expires.
  final bool requestCooldownActive;

  /// Seed for the display countdown, set to [_requestCooldown] seconds on each
  /// successful send. The widget owns the live decrement; this is only the seed.
  final int requestCooldownSeconds;

  /// Monotonic counter bumped on each successful (re)send so the widget's
  /// countdown can restart even when the seeded seconds repeat (60 → 60).
  final int requestCooldownTick;

  /// Set on a successful confirm; the scheduled deletion UTC timestamp.
  final DateTime? scheduledAt;

  /// Last failure to surface; null means no error shown.
  final Failure? failure;

  AccountDeletionState copyWith({
    DeletionStep? step,
    bool? submitting,
    bool? requestCooldownActive,
    int? requestCooldownSeconds,
    int? requestCooldownTick,
    DateTime? scheduledAt,
    Failure? failure,
    bool clearFailure = false,
  }) => AccountDeletionState(
    step: step ?? this.step,
    submitting: submitting ?? this.submitting,
    requestCooldownActive: requestCooldownActive ?? this.requestCooldownActive,
    requestCooldownSeconds:
        requestCooldownSeconds ?? this.requestCooldownSeconds,
    requestCooldownTick: requestCooldownTick ?? this.requestCooldownTick,
    scheduledAt: scheduledAt ?? this.scheduledAt,
    failure: clearFailure ? null : (failure ?? this.failure),
  );

  @override
  List<Object?> get props => [
    step,
    submitting,
    requestCooldownActive,
    requestCooldownSeconds,
    requestCooldownTick,
    scheduledAt,
    failure,
  ];
}

@riverpod
class AccountDeletionController extends _$AccountDeletionController {
  Timer? _requestCooldownTimer;

  @override
  AccountDeletionState build() {
    ref.onDispose(() => _requestCooldownTimer?.cancel());
    return AccountDeletionState.initial();
  }

  /// Requests a deletion code (initial send and resend share this path).
  /// On success advances to [DeletionStep.awaitingCode] and starts the
  /// client-side debounce.
  Future<void> requestCode() => _send();

  /// Submits [code] for confirmation. On success advances to
  /// [DeletionStep.scheduled] and records the [DeletionSchedule.scheduledAt].
  /// On failure stays on [DeletionStep.awaitingCode] so the user can retry
  /// without re-requesting a code.
  Future<void> confirmCode(String code) async {
    state = state.copyWith(submitting: true, clearFailure: true);
    final repo = ref.read(accountDeletionRepositoryProvider);
    final result = await repo.confirmDeletion(code);
    if (!ref.mounted) return;
    result.fold(
      _applyFailure,
      (schedule) => state = state.copyWith(
        step: DeletionStep.scheduled,
        submitting: false,
        scheduledAt: schedule.scheduledAt,
        clearFailure: true,
      ),
    );
  }

  /// Cancels a scheduled deletion during the grace period. On success advances
  /// to [DeletionStep.cancelled]; on failure stays on [DeletionStep.scheduled]
  /// and surfaces the [Failure] so the user can retry.
  Future<void> cancelDeletion() async {
    state = state.copyWith(submitting: true, clearFailure: true);
    final repo = ref.read(accountDeletionRepositoryProvider);
    final result = await repo.cancelDeletion();
    if (!ref.mounted) return;
    result.fold(
      (failure) => state = state.copyWith(submitting: false, failure: failure),
      (_) => state = state.copyWith(
        step: DeletionStep.cancelled,
        submitting: false,
        clearFailure: true,
      ),
    );
  }

  /// Resets the controller to [AccountDeletionState.initial], cancelling any
  /// in-flight timers.
  void reset() {
    _requestCooldownTimer?.cancel();
    state = AccountDeletionState.initial();
  }

  Future<void> _send() async {
    state = state.copyWith(submitting: true, clearFailure: true);
    final repo = ref.read(accountDeletionRepositoryProvider);
    final result = await repo.requestDeletion();
    if (!ref.mounted) return;
    result.fold(_applyFailure, (_) {
      state = state.copyWith(
        step: DeletionStep.awaitingCode,
        submitting: false,
        requestCooldownActive: true,
        requestCooldownSeconds: _requestCooldown.inSeconds,
        requestCooldownTick: state.requestCooldownTick + 1,
        clearFailure: true,
      );
      _startRequestCooldown();
    });
  }

  /// Applies a [failure] to the state. A `429 OTP_RATE_LIMIT`
  /// ([AuthRateLimitFailure]) is the auth platform throttling the OTP channel,
  /// so it engages the same [_requestCooldown] debounce a successful send does;
  /// otherwise the throttled buttons would re-enable instantly and let the user
  /// keep hitting the rate-limited endpoint. Any other failure just surfaces.
  void _applyFailure(Failure failure) {
    if (failure is AuthRateLimitFailure) {
      state = state.copyWith(
        submitting: false,
        failure: failure,
        requestCooldownActive: true,
        requestCooldownSeconds: _requestCooldown.inSeconds,
        requestCooldownTick: state.requestCooldownTick + 1,
      );
      _startRequestCooldown();
      return;
    }
    state = state.copyWith(submitting: false, failure: failure);
  }

  void _startRequestCooldown() {
    _requestCooldownTimer?.cancel();
    _requestCooldownTimer = Timer(_requestCooldown, () {
      state = state.copyWith(requestCooldownActive: false, clearFailure: true);
    });
  }
}
