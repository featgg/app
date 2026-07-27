import 'package:equatable/equatable.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../connections/domain/connection.dart';
import '../domain/profile.dart';
import '../domain/profile_providers.dart';
import 'profile_provider.dart';

part 'profile_edit_controller.g.dart';

/// Immutable state for the profile-edit controller: the form as it was opened,
/// the form as it stands, and the outcome of the last save.
final class ProfileEditState extends Equatable {
  const ProfileEditState({
    required this.seed,
    required this.draft,
    required this.submitting,
    this.fieldErrors = const {},
    this.failure,
    this.saved = false,
  });

  /// The profile as the screen opened it.
  final ProfileEdit seed;

  /// The edit as it currently stands. Every field the form can change lives
  /// here rather than in the widget, so what Save submits and what decides
  /// whether Save is live are the same value.
  final ProfileEdit draft;

  /// True while the update call is in flight; the Save action shows a spinner
  /// and is disabled.
  final bool submitting;

  /// Per-field client-validation errors; empty when the edit is valid.
  final Set<ProfileEditField> fieldErrors;

  /// Last backend failure to surface to the user; null means no error shown.
  final Failure? failure;

  /// True once a save round-trips successfully; drives the pop-and-snackbar.
  final bool saved;

  /// Whether the form differs from what it opened with. An unedited form has
  /// nothing to write, so Save is live only here.
  bool get isDirty => draft != seed;

  ProfileEditState copyWith({
    ProfileEdit? draft,
    bool? submitting,
    Set<ProfileEditField>? fieldErrors,
    Failure? failure,
    bool? saved,
    bool clearFailure = false,
    bool clearFieldErrors = false,
  }) => ProfileEditState(
    seed: seed,
    draft: draft ?? this.draft,
    submitting: submitting ?? this.submitting,
    fieldErrors: clearFieldErrors ? {} : (fieldErrors ?? this.fieldErrors),
    failure: clearFailure ? null : (failure ?? this.failure),
    saved: saved ?? this.saved,
  );

  @override
  List<Object?> get props => [
    seed,
    draft,
    submitting,
    fieldErrors,
    failure,
    saved,
  ];
}

/// Owns the edit form. Keyed by the profile it opens on, so the form seeds
/// itself rather than being written to from a widget life-cycle — which
/// Riverpod forbids, and which would leave the first frame unseeded anyway.
@riverpod
class ProfileEditController extends _$ProfileEditController {
  @override
  ProfileEditState build(Profile profile) {
    final bioRaw = (profile.bio ?? '').trim();
    final edit = ProfileEdit(
      displayName: profile.displayName.trim(),
      bio: bioRaw.isEmpty ? null : bioRaw,
      theme: profile.theme,
      // Privacy is not edited here. Carrying the opened value through is what
      // keeps an edit-save from overwriting a privacy change made in Settings.
      privacy: profile.privacy,
      featuredPlatform: profile.featuredPlatform,
      headerPlatform: profile.headerPlatform,
    );
    return ProfileEditState(seed: edit, draft: edit, submitting: false);
  }

  void editDisplayName(String value) =>
      _amend((draft) => draft.copyWith(displayName: value.trim()));

  void editBio(String value) {
    final trimmed = value.trim();
    _amend(
      (draft) => draft.copyWith(bio: () => trimmed.isEmpty ? null : trimmed),
    );
  }

  void selectTheme(ProfileTheme theme) =>
      _amend((draft) => draft.copyWith(theme: theme));

  void selectFeaturedPlatform(Platform? platform) =>
      _amend((draft) => draft.copyWith(featuredPlatform: () => platform));

  void selectHeaderPlatform(Platform? platform) =>
      _amend((draft) => draft.copyWith(headerPlatform: () => platform));

  void _amend(ProfileEdit Function(ProfileEdit draft) change) =>
      state = state.copyWith(draft: change(state.draft));

  /// Validates the draft; on a client error sets fieldErrors and does not call
  /// the backend. On success calls updateMyProfile; Right → invalidate the read
  /// provider and set saved:true; Left → carry the Failure, keeping the draft
  /// so nothing the user typed is lost.
  Future<void> submit() async {
    final edit = state.draft;
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
