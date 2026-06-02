import 'package:equatable/equatable.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../domain/auth_domain.dart';

part 'otp_controller.g.dart';

/// Conservative client-side cooldown after a rate-limited response. The server
/// enforces its own window; this only prevents back-to-back retries.
const _cooldown = Duration(seconds: 30);

/// Step of the email-OTP flow the screen renders.
enum OtpStep { email, code }

/// Immutable controller state.
final class OtpState extends Equatable {
  const OtpState({
    required this.step,
    required this.email,
    required this.cooldownActive,
    this.failure,
  });

  factory OtpState.initial() =>
      const OtpState(step: OtpStep.email, email: '', cooldownActive: false);

  final OtpStep step;
  final String email;

  /// True while backing off after a rate-limited response; the rate-limited
  /// actions (send, resend, verify) are disabled until the cooldown elapses.
  final bool cooldownActive;

  /// Last expected failure to surface to the user; null means no error shown.
  final Failure? failure;

  OtpState copyWith({
    OtpStep? step,
    String? email,
    bool? cooldownActive,
    Failure? failure,
    bool clearFailure = false,
  }) => OtpState(
    step: step ?? this.step,
    email: email ?? this.email,
    cooldownActive: cooldownActive ?? this.cooldownActive,
    failure: clearFailure ? null : (failure ?? this.failure),
  );

  @override
  List<Object?> get props => [step, email, cooldownActive, failure];
}

@riverpod
class OtpController extends _$OtpController {
  @override
  OtpState build() => OtpState.initial();

  /// Email step: request a 6-digit code. On success advances to [OtpStep.code].
  /// On [AuthRateLimitFailure] sets [OtpState.cooldownActive] and schedules
  /// re-enable after [_cooldown].
  Future<void> requestCode(String email) async {
    state = state.copyWith(clearFailure: true);
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.requestEmailCode(email);
    result.fold(
      (failure) {
        if (failure is AuthRateLimitFailure) {
          state = state.copyWith(
            email: email,
            cooldownActive: true,
            failure: failure,
          );
          _scheduleCooldownEnd();
        } else {
          state = state.copyWith(email: email, failure: failure);
        }
      },
      (_) {
        state = state.copyWith(
          step: OtpStep.code,
          email: email,
          clearFailure: true,
        );
      },
    );
  }

  /// Code step: verify the 6-digit code. On success the SDK persists the
  /// session; the auth-status stream flip drives the router redirect —
  /// this controller does NOT navigate. On [AuthRateLimitFailure] sets
  /// [OtpState.cooldownActive] so the screen backs the verify action off.
  Future<void> verifyCode(String code) async {
    state = state.copyWith(clearFailure: true);
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.verifyEmailCode(email: state.email, code: code);
    result.fold(
      (failure) {
        if (failure is AuthRateLimitFailure) {
          state = state.copyWith(cooldownActive: true, failure: failure);
          _scheduleCooldownEnd();
        } else {
          state = state.copyWith(failure: failure);
        }
      },
      (_) {
        // Navigation is driven by the auth-status stream; nothing to do here.
      },
    );
  }

  /// Resend the code while on the code step (same back-off rules as requestCode).
  Future<void> resendCode() async {
    await requestCode(state.email);
  }

  /// Return from the code step to the email step.
  void editEmail() {
    state = OtpState.initial();
  }

  void _scheduleCooldownEnd() {
    Future.delayed(_cooldown, () {
      // Guard: notifier may have been disposed by the time the timer fires.
      if (!ref.mounted) return;
      state = state.copyWith(cooldownActive: false, clearFailure: true);
    });
  }
}
