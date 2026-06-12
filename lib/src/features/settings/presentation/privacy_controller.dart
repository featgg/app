import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../profile/domain/profile.dart';
import '../../profile/domain/profile_providers.dart';
import 'settings_current_privacy_provider.dart';

part 'privacy_controller.g.dart';

/// Thin notifier that writes a single privacy change through the existing
/// profile update path.
///
/// `setPrivacy` reads the current profile to preserve every other writable
/// field, mutates only `privacy`, calls `updateMyProfile`, then invalidates
/// `settingsCurrentPrivacyProvider` on success. On a Left the Failure is
/// surfaced as AsyncError — the screen maps it via `FailureL10n.localizedMessage`.
///
/// No reference to `profileProvider` (a profile-presentation symbol) appears
/// here; this notifier depends only on profile domain.
@riverpod
class PrivacyController extends _$PrivacyController {
  @override
  FutureOr<void> build() {}

  Future<void> setPrivacy(ProfilePrivacy privacy) async {
    state = const AsyncLoading();

    final repo = ref.read(profileRepositoryProvider);

    final fetchResult = await repo.fetchMyProfile();
    final profile = fetchResult.fold((failure) {
      state = AsyncError(failure, StackTrace.current);
      return null;
    }, (p) => p);
    if (profile == null) return;

    final edit = ProfileEdit(
      displayName: profile.displayName,
      bio: profile.bio,
      theme: profile.theme,
      privacy: privacy,
      featuredPlatform: profile.featuredPlatform,
    );

    final updateResult = await repo.updateMyProfile(edit);
    updateResult.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
      },
      (_) {
        ref.invalidate(settingsCurrentPrivacyProvider);
        state = const AsyncData(null);
      },
    );
  }
}
