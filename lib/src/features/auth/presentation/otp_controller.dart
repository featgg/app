import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../domain/auth_domain.dart';

part 'otp_controller.g.dart';

/// Client-side back-off after a rate-limited response. The server enforces its
/// own window, which the client cannot read and may be longer; this only
/// disables the rate-limited action so the user does not hammer it. Kept near
/// the auth platform's typical window so the action does not re-enable only to
/// be rate-limited again.
const _cooldown = Duration(seconds: 60);

/// Step of the email-OTP flow the screen renders.
enum OtpStep { email, code }

/// Immutable controller state.
final class OtpState extends Equatable {
  const OtpState({
    required this.step,
    required this.email,
    required this.submitting,
    required this.cooldownActive,
    this.failure,
  });

  factory OtpState.initial() => const OtpState(
    step: OtpStep.email,
    email: '',
    submitting: false,
    cooldownActive: false,
  );

  final OtpStep step;
  final String email;

  /// True while a request/verify call is in flight; the primary action shows a
  /// spinner and is disabled.
  final bool submitting;

  /// True while backing off after a rate-limited response; the rate-limited
  /// actions are disabled until the cooldown elapses.
  final bool cooldownActive;

  /// Last expected failure to surface to the user; null means no error shown.
  final Failure? failure;

  OtpState copyWith({
    OtpStep? step,
    String? email,
    bool? submitting,
    bool? cooldownActive,
    Failure? failure,
    bool clearFailure = false,
  }) => OtpState(
    step: step ?? this.step,
    email: email ?? this.email,
    submitting: submitting ?? this.submitting,
    cooldownActive: cooldownActive ?? this.cooldownActive,
    failure: clearFailure ? null : (failure ?? this.failure),
  );

  @override
  List<Object?> get props => [step, email, submitting, cooldownActive, failure];
}

@riverpod
class OtpController extends _$OtpController {
  Timer? _cooldownTimer;

  @override
  OtpState build() {
    ref.onDispose(() => _cooldownTimer?.cancel());
    return OtpState.initial();
  }

  /// Email step: request a 6-digit code. On success advances to [OtpStep.code].
  /// On [AuthRateLimitFailure] starts the back-off (see [_startCooldown]).
  Future<void> requestCode(String email) async {
    state = state.copyWith(submitting: true, clearFailure: true);
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.requestEmailCode(email);
    result.fold(
      (failure) {
        if (failure is AuthRateLimitFailure) {
          state = state.copyWith(
            email: email,
            submitting: false,
            cooldownActive: true,
            failure: failure,
          );
          _startCooldown();
        } else {
          state = state.copyWith(
            email: email,
            submitting: false,
            failure: failure,
          );
        }
      },
      (_) {
        state = state.copyWith(
          step: OtpStep.code,
          email: email,
          submitting: false,
          clearFailure: true,
        );
      },
    );
  }

  /// Code step: verify the 6-digit code. On success the SDK persists the
  /// session; the auth-status stream flip drives the router redirect — this
  /// controller does NOT navigate. On [AuthRateLimitFailure] starts the
  /// back-off so the screen disables the verify action.
  Future<void> verifyCode(String code) async {
    state = state.copyWith(submitting: true, clearFailure: true);
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.verifyEmailCode(email: state.email, code: code);
    result.fold(
      (failure) {
        if (failure is AuthRateLimitFailure) {
          state = state.copyWith(
            submitting: false,
            cooldownActive: true,
            failure: failure,
          );
          _startCooldown();
        } else {
          state = state.copyWith(submitting: false, failure: failure);
        }
      },
      (_) {
        state = state.copyWith(submitting: false);
      },
    );
  }

  /// Resend the code while on the code step (same back-off rules as requestCode).
  Future<void> resendCode() async {
    await requestCode(state.email);
  }

  /// Return from the code step to the email step.
  void editEmail() {
    _cooldownTimer?.cancel();
    state = OtpState.initial();
  }

  /// Starts (or restarts) the back-off. Cancelling any in-flight timer first
  /// means a fresh rate-limit reschedules from scratch: a longer server block
  /// that 429s again on retry extends the cooldown rather than re-enabling
  /// early. The timer is also cancelled on dispose and on [editEmail].
  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(_cooldown, () {
      state = state.copyWith(cooldownActive: false, clearFailure: true);
    });
  }
}
