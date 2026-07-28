import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../connections/domain/connection.dart';
import '../../profile/domain/profile.dart';
import '../../profile/domain/profile_providers.dart';
import 'settings_feed_preview_provider.dart';

part 'feed_preview_controller.g.dart';

/// Writes the discovery-feed preview choice through the existing profile
/// update path.
///
/// Mirrors the privacy controller: read the current profile so every other
/// writable field is preserved, change only `featuredPlatform`, then
/// invalidate the settings read seam on success. On a Left the Failure is
/// surfaced as AsyncError and the screen maps it to copy.
@riverpod
class FeedPreviewController extends _$FeedPreviewController {
  @override
  FutureOr<void> build() {}

  /// Pins [platform] as the feed preview, or clears the pin with null so the
  /// feed falls back to its own choice.
  Future<void> setFeaturedPlatform(Platform? platform) async {
    state = const AsyncLoading();

    final repo = ref.read(profileRepositoryProvider);

    final fetchResult = await repo.fetchMyProfile();
    final profile = fetchResult.fold((failure) {
      if (ref.mounted) state = AsyncError(failure, StackTrace.current);
      return null;
    }, (p) => p);
    if (profile == null) return;

    final edit = ProfileEdit(
      displayName: profile.displayName,
      bio: profile.bio,
      theme: profile.theme,
      privacy: profile.privacy,
      featuredPlatform: platform,
      headerPlatform: profile.headerPlatform,
    );

    final updateResult = await repo.updateMyProfile(edit);
    if (!ref.mounted) return;
    updateResult.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
      },
      (_) {
        ref.invalidate(settingsFeedPreviewProvider);
        state = const AsyncData(null);
      },
    );
  }
}
