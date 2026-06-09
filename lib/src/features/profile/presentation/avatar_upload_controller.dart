import 'dart:async';

import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../core/observability/observability.dart';
import '../domain/avatar_providers.dart';
import 'avatar_picker.dart';
import 'profile_provider.dart';

part 'avatar_upload_controller.g.dart';

/// Fallback cooldown duration when the server 429 carries no usable
/// `retry_after`. Mirrors the documented ~1-per-60s refill interval.
const Duration _avatarCooldownFallback = Duration(seconds: 60);

/// Coarse upload-pipeline status.
enum AvatarUploadStatus { idle, picking, uploading, success, error }

/// Immutable state for the avatar-upload pipeline.
final class AvatarUploadState extends Equatable {
  const AvatarUploadState({
    required this.status,
    this.failure,
    this.newAvatarUrl,
    this.cooldownUntil,
  });

  final AvatarUploadStatus status;

  /// Set when [status] is [AvatarUploadStatus.error].
  final Failure? failure;

  /// Set when [status] is [AvatarUploadStatus.success].
  final String? newAvatarUrl;

  /// When non-null and in the future, the upload action is disabled.
  final DateTime? cooldownUntil;

  /// Whether the upload action is currently on cooldown.
  bool get onCooldown =>
      cooldownUntil != null && clock.now().isBefore(cooldownUntil!);

  @override
  List<Object?> get props => [status, failure, newAvatarUrl, cooldownUntil];

  AvatarUploadState copyWith({
    AvatarUploadStatus? status,
    Failure? failure,
    String? newAvatarUrl,
    DateTime? cooldownUntil,
    bool clearFailure = false,
    bool clearCooldown = false,
  }) => AvatarUploadState(
    status: status ?? this.status,
    failure: clearFailure ? null : (failure ?? this.failure),
    newAvatarUrl: newAvatarUrl ?? this.newAvatarUrl,
    cooldownUntil: clearCooldown ? null : (cooldownUntil ?? this.cooldownUntil),
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

  void _scheduleCooldownTimer(Duration duration) {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(duration, () {
      if (ref.mounted) {
        state = state.copyWith(clearCooldown: true);
      }
    });
  }

  /// Runs the full pick → crop → compress → upload pipeline.
  ///
  /// [pickAndCrop] is supplied by the widget; it closes over the widget's UI
  /// context so the controller stays context-free (no UI types in the provider).
  /// Returns `null` on cancel, throws [AvatarProcessingException] on a local
  /// decode/crop fault (mapped to [MediaProcessingFailure]), or throws any
  /// other exception (mapped to [UnexpectedFailure] + crash-reported).
  /// On success, invalidates [profileProvider] so the new avatar URL re-renders.
  /// Short-circuits when [onCooldown].
  Future<void> pickAndUpload(Future<AvatarPick?> Function() pickAndCrop) async {
    if (state.onCooldown) return;

    state = state.copyWith(
      status: AvatarUploadStatus.picking,
      clearFailure: true,
    );

    final AvatarPick? pick;
    try {
      pick = await pickAndCrop();
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
          final cooldown = failure.retryAfterSeconds != null
              ? Duration(seconds: failure.retryAfterSeconds!)
              : _avatarCooldownFallback;
          state = state.copyWith(
            status: AvatarUploadStatus.error,
            failure: failure,
            cooldownUntil: clock.now().add(cooldown),
          );
          _scheduleCooldownTimer(cooldown);
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
}
