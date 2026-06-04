import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../core/observability/observability.dart';
import '../domain/avatar_providers.dart';
import 'avatar_picker.dart';
import 'profile_provider.dart';

part 'avatar_upload_controller.g.dart';

/// Fixed fallback window used when the server omits retry_after. Mirrors the
/// documented ≈60s per-user cooldown from the avatar upload brief.
const _cooldownFallback = Duration(seconds: 60);

/// Coarse upload-pipeline status.
enum AvatarUploadStatus { idle, picking, uploading, success, error, cooldown }

/// Immutable state for the avatar-upload pipeline.
final class AvatarUploadState extends Equatable {
  const AvatarUploadState({
    required this.status,
    this.failure,
    this.newAvatarUrl,
    this.cooldownSecondsRemaining = 0,
  });

  final AvatarUploadStatus status;

  /// Set when [status] is [AvatarUploadStatus.error] or
  /// [AvatarUploadStatus.cooldown].
  final Failure? failure;

  /// Set when [status] is [AvatarUploadStatus.success].
  final String? newAvatarUrl;

  /// Seed for the widget's display countdown when [status] is
  /// [AvatarUploadStatus.cooldown]. 0 means retry_after was absent; the widget
  /// shows a generic "try again shortly" message in that case. The widget owns
  /// the live decrement — this field is the initial seed only (mirrors
  /// OtpState.resendSecondsRemaining).
  final int cooldownSecondsRemaining;

  @override
  List<Object?> get props => [
    status,
    failure,
    newAvatarUrl,
    cooldownSecondsRemaining,
  ];

  AvatarUploadState copyWith({
    AvatarUploadStatus? status,
    Failure? failure,
    String? newAvatarUrl,
    bool clearFailure = false,
    int? cooldownSecondsRemaining,
  }) => AvatarUploadState(
    status: status ?? this.status,
    failure: clearFailure ? null : (failure ?? this.failure),
    newAvatarUrl: newAvatarUrl ?? this.newAvatarUrl,
    cooldownSecondsRemaining:
        cooldownSecondsRemaining ?? this.cooldownSecondsRemaining,
  );
}

@riverpod
class AvatarUploadController extends _$AvatarUploadController {
  Timer? _cooldownTimer;

  @override
  AvatarUploadState build() {
    ref.onDispose(() => _cooldownTimer?.cancel());
    return const AvatarUploadState(status: AvatarUploadStatus.idle);
  }

  /// Runs the full pick → crop → compress → upload pipeline.
  ///
  /// Cancelling at either the gallery-pick or the crop step returns to idle
  /// without an error. On success, invalidates [profileProvider] so the new
  /// avatar URL re-renders. Throws [AvatarProcessingException] on a local
  /// decode/crop fault, which is mapped to [MediaProcessingFailure].
  Future<void> pickAndUpload(BuildContext context) async {
    state = state.copyWith(
      status: AvatarUploadStatus.picking,
      clearFailure: true,
    );

    final picker = ref.read(avatarPickerProvider);
    final AvatarPick? pick;
    try {
      pick = await picker.pickAndCrop(context);
    } catch (e, st) {
      // Guard against a disposed notifier before writing state or reporting.
      if (!ref.mounted) return;
      if (e is AvatarProcessingException) {
        state = state.copyWith(
          status: AvatarUploadStatus.error,
          failure: const MediaProcessingFailure(),
        );
      } else {
        // Catching is required for UX recovery; reporting is required for
        // observability — both must happen at the same site.
        ref.read(crashReporterProvider).reportError(e, st);
        state = state.copyWith(
          status: AvatarUploadStatus.error,
          failure: UnexpectedFailure(message: e.toString()),
        );
      }
      return;
    }

    // Route may pop mid-flight; skip state writes on a disposed notifier.
    if (!ref.mounted) return;

    if (pick == null) {
      state = state.copyWith(
        status: AvatarUploadStatus.idle,
        clearFailure: true,
      );
      return;
    }

    state = state.copyWith(
      status: AvatarUploadStatus.uploading,
      clearFailure: true,
    );

    final repo = ref.read(avatarRepositoryProvider);
    final result = await repo.uploadAvatar(
      bytes: pick.bytes,
      contentType: pick.contentType,
    );

    if (!ref.mounted) return;

    result.fold(
      (failure) {
        if (failure is RateLimitFailure) {
          _startCooldown(failure);
        } else {
          state = state.copyWith(
            status: AvatarUploadStatus.error,
            failure: failure,
          );
        }
      },
      (url) {
        ref.invalidate(profileProvider);
        state = state.copyWith(
          status: AvatarUploadStatus.success,
          newAvatarUrl: url,
          clearFailure: true,
        );
      },
    );
  }

  /// Starts (or restarts) the upload cooldown. Cancelling any in-flight timer
  /// first means a re-upload that also 429s extends the window rather than
  /// re-enabling early (mirrors OtpController._startSendCooldown).
  void _startCooldown(RateLimitFailure failure) {
    final windowSeconds =
        failure.retryAfterSeconds ?? _cooldownFallback.inSeconds;
    state = state.copyWith(
      status: AvatarUploadStatus.cooldown,
      failure: failure,
      cooldownSecondsRemaining: failure.retryAfterSeconds ?? 0,
    );
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(Duration(seconds: windowSeconds), () {
      if (!ref.mounted) return;
      state = state.copyWith(
        status: AvatarUploadStatus.idle,
        clearFailure: true,
        cooldownSecondsRemaining: 0,
      );
    });
  }
}
