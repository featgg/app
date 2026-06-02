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

/// Short proactive anti-mash throttle on resend after a successful send. Kept
/// brief on purpose: a long client-side block is bypassable (close/reopen the
/// app) and punishes honest mistakes — the server's 429 is the authoritative
/// limit, handled reactively via [_cooldown]. Seeded into the widget's ticker.
const _resendInterval = Duration(seconds: 5);

/// Step of the email-OTP flow the screen renders.
enum OtpStep { email, code }

/// Immutable controller state.
final class OtpState extends Equatable {
  const OtpState({
    required this.step,
    required this.email,
    required this.submitting,
    required this.sendCooldownActive,
    required this.verifyCooldownActive,
    this.resendSecondsRemaining = 0,
    this.failure,
  });

  factory OtpState.initial() => const OtpState(
    step: OtpStep.email,
    email: '',
    submitting: false,
    sendCooldownActive: false,
    verifyCooldownActive: false,
  );

  final OtpStep step;
  final String email;

  /// True while a request/verify call is in flight; the primary action shows a
  /// spinner and is disabled.
  final bool submitting;

  /// True while backing off after a rate-limited send/resend response (429).
  /// Disables the send, resend, and "Change email" actions.
  final bool sendCooldownActive;

  /// True while backing off after a rate-limited verify response (429).
  /// Disables only the Verify action; independent of the send cooldown.
  final bool verifyCooldownActive;

  /// Seconds remaining in the proactive resend window seeded on each successful
  /// send. The widget owns the live decrement via a `Timer.periodic`; this field
  /// is only the initial seed (set to [_resendInterval] seconds on send, 0
  /// otherwise). When > 0 the widget starts its countdown; when 0 resend is
  /// available.
  final int resendSecondsRemaining;

  /// Last expected failure to surface to the user; null means no error shown.
  final Failure? failure;

  OtpState copyWith({
    OtpStep? step,
    String? email,
    bool? submitting,
    bool? sendCooldownActive,
    bool? verifyCooldownActive,
    int? resendSecondsRemaining,
    Failure? failure,
    bool clearFailure = false,
  }) => OtpState(
    step: step ?? this.step,
    email: email ?? this.email,
    submitting: submitting ?? this.submitting,
    sendCooldownActive: sendCooldownActive ?? this.sendCooldownActive,
    verifyCooldownActive: verifyCooldownActive ?? this.verifyCooldownActive,
    resendSecondsRemaining:
        resendSecondsRemaining ?? this.resendSecondsRemaining,
    failure: clearFailure ? null : (failure ?? this.failure),
  );

  @override
  List<Object?> get props => [
    step,
    email,
    submitting,
    sendCooldownActive,
    verifyCooldownActive,
    resendSecondsRemaining,
    failure,
  ];
}

@riverpod
class OtpController extends _$OtpController {
  Timer? _sendCooldownTimer;
  Timer? _verifyCooldownTimer;

  @override
  OtpState build() {
    ref.onDispose(() {
      _sendCooldownTimer?.cancel();
      _verifyCooldownTimer?.cancel();
    });
    return OtpState.initial();
  }

  /// Email step: request a 6-digit code. On success advances to [OtpStep.code]
  /// and seeds the proactive resend window. On [AuthRateLimitFailure] starts
  /// the send back-off (see [_startSendCooldown]).
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
            sendCooldownActive: true,
            failure: failure,
          );
          _startSendCooldown();
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
          resendSecondsRemaining: _resendInterval.inSeconds,
        );
      },
    );
  }

  /// Code step: verify the 6-digit code. On success the SDK persists the
  /// session; the auth-status stream flip drives the router redirect — this
  /// controller does NOT navigate. On [AuthRateLimitFailure] starts the verify
  /// back-off. On any failure records [lastFailedCode] to prevent identical
  /// re-submissions.
  Future<void> verifyCode(String code) async {
    state = state.copyWith(submitting: true, clearFailure: true);
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.verifyEmailCode(email: state.email, code: code);
    result.fold(
      (failure) {
        if (failure is AuthRateLimitFailure) {
          state = state.copyWith(
            submitting: false,
            verifyCooldownActive: true,
            failure: failure,
          );
          _startVerifyCooldown();
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
    _sendCooldownTimer?.cancel();
    _verifyCooldownTimer?.cancel();
    state = OtpState.initial();
  }

  /// Starts (or restarts) the send back-off. Cancelling any in-flight timer
  /// first means a fresh rate-limit reschedules from scratch: a longer server
  /// block that 429s again on retry extends the cooldown rather than
  /// re-enabling early.
  void _startSendCooldown() {
    _sendCooldownTimer?.cancel();
    _sendCooldownTimer = Timer(_cooldown, () {
      state = state.copyWith(sendCooldownActive: false, clearFailure: true);
    });
  }

  /// Starts (or restarts) the verify back-off; independent of the send bucket.
  void _startVerifyCooldown() {
    _verifyCooldownTimer?.cancel();
    _verifyCooldownTimer = Timer(_cooldown, () {
      state = state.copyWith(verifyCooldownActive: false, clearFailure: true);
    });
  }
}
