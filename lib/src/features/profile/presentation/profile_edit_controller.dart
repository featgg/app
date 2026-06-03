import 'package:equatable/equatable.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../domain/profile.dart';
import '../domain/profile_providers.dart';
import 'profile_provider.dart';

part 'profile_edit_controller.g.dart';

/// Immutable state for the profile-edit controller.
final class ProfileEditState extends Equatable {
  const ProfileEditState({
    required this.submitting,
    this.fieldErrors = const {},
    this.failure,
    this.saved = false,
  });

  factory ProfileEditState.initial() =>
      const ProfileEditState(submitting: false);

  /// True while the update call is in flight; the Save action shows a spinner
  /// and is disabled.
  final bool submitting;

  /// Per-field client-validation errors; empty when the edit is valid.
  final Set<ProfileEditField> fieldErrors;

  /// Last backend failure to surface to the user; null means no error shown.
  final Failure? failure;

  /// True once a save round-trips successfully; drives the pop-and-snackbar.
  final bool saved;

  ProfileEditState copyWith({
    bool? submitting,
    Set<ProfileEditField>? fieldErrors,
    Failure? failure,
    bool? saved,
    bool clearFailure = false,
    bool clearFieldErrors = false,
  }) => ProfileEditState(
    submitting: submitting ?? this.submitting,
    fieldErrors: clearFieldErrors ? {} : (fieldErrors ?? this.fieldErrors),
    failure: clearFailure ? null : (failure ?? this.failure),
    saved: saved ?? this.saved,
  );

  @override
  List<Object?> get props => [submitting, fieldErrors, failure, saved];
}

@riverpod
class ProfileEditController extends _$ProfileEditController {
  @override
  ProfileEditState build() => ProfileEditState.initial();

  /// Validates [edit]; on a client error sets fieldErrors and does not call the
  /// backend. On success calls updateMyProfile; Right → invalidate the read
  /// provider and set saved:true; Left → carry the Failure (input preserved by
  /// the widget's own controllers).
  Future<void> submit(ProfileEdit edit) async {
    final fieldErrors = edit.validate();
    if (fieldErrors.isNotEmpty) {
      state = state.copyWith(fieldErrors: fieldErrors, clearFailure: true);
      return;
    }

    state = state.copyWith(
      submitting: true,
      clearFieldErrors: true,
      clearFailure: true,
    );

    final repo = ref.read(profileRepositoryProvider);
    final result = await repo.updateMyProfile(edit);

    result.fold(
      (failure) {
        state = state.copyWith(submitting: false, failure: failure);
      },
      (_) {
        ref.invalidate(profileProvider);
        state = state.copyWith(submitting: false, saved: true);
      },
    );
  }
}
