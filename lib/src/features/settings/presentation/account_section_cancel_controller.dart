import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/settings_providers.dart';
import 'settings_deletion_status_provider.dart';

part 'account_section_cancel_controller.g.dart';

/// Cancels a pending deletion from the Account section banner and refreshes the
/// profile-derived pending read so the banner clears on the next read.
///
/// A focused controller separate from the multi-step `AccountDeletionController`:
/// the banner acts on pending state read from the profile, not on that flow's
/// `DeletionStep` state, and must invalidate `settingsDeletionStatusProvider`.
/// Reuses the same `cancelDeletion` Either path — no duplicated backend logic.
@riverpod
class AccountSectionCancelController extends _$AccountSectionCancelController {
  // Synchronous build (no initial AsyncLoading), matching the sibling
  // sign-out/privacy controllers: the screen's success listener keys off a
  // loading→data transition, so an async build's init transition would fire the
  // cancel-success snackbar on first render. A cancel() call still goes through
  // AsyncLoading explicitly.
  @override
  FutureOr<void> build() {}

  Future<void> cancel() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await ref
          .read(accountDeletionRepositoryProvider)
          .cancelDeletion();
      result.fold((f) => throw f, (_) {});
      ref.invalidate(settingsDeletionStatusProvider);
    });
  }
}
