import 'package:equatable/equatable.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../core/observability/observability.dart';
import '../domain/avatar_providers.dart';
import 'avatar_picker.dart';
import 'profile_provider.dart';

part 'avatar_upload_controller.g.dart';

/// Coarse upload-pipeline status.
enum AvatarUploadStatus { idle, picking, uploading, success, error }

/// Immutable state for the avatar-upload pipeline.
final class AvatarUploadState extends Equatable {
  const AvatarUploadState({
    required this.status,
    this.failure,
    this.newAvatarUrl,
  });

  final AvatarUploadStatus status;

  /// Set when [status] is [AvatarUploadStatus.error].
  final Failure? failure;

  /// Set when [status] is [AvatarUploadStatus.success].
  final String? newAvatarUrl;

  @override
  List<Object?> get props => [status, failure, newAvatarUrl];

  AvatarUploadState copyWith({
    AvatarUploadStatus? status,
    Failure? failure,
    String? newAvatarUrl,
    bool clearFailure = false,
  }) => AvatarUploadState(
    status: status ?? this.status,
    failure: clearFailure ? null : (failure ?? this.failure),
    newAvatarUrl: newAvatarUrl ?? this.newAvatarUrl,
  );
}

@riverpod
class AvatarUploadController extends _$AvatarUploadController {
  @override
  AvatarUploadState build() {
    return const AvatarUploadState(status: AvatarUploadStatus.idle);
  }

  /// Runs the full pick → crop → compress → upload pipeline.
  ///
  /// [pickAndCrop] is supplied by the widget; it closes over the widget's UI
  /// context so the controller stays context-free (no UI types in the provider).
  /// Returns `null` on
  /// cancel, throws [AvatarProcessingException] on a local decode/crop fault
  /// (mapped to [MediaProcessingFailure]), or throws any other exception
  /// (mapped to [UnexpectedFailure] + crash-reported).
  /// On success, invalidates [profileProvider] so the new avatar URL re-renders.
  Future<void> pickAndUpload(Future<AvatarPick?> Function() pickAndCrop) async {
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
      (failure) => state = state.copyWith(
        status: AvatarUploadStatus.error,
        failure: failure,
      ),
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
