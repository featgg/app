import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../profile/domain/profile.dart';
import '../../profile/domain/profile_providers.dart';

part 'settings_current_privacy_provider.g.dart';

/// Settings-owned read seam for the current profile privacy value.
///
/// Depends only on the profile domain (`profileRepositoryProvider`). Settings
/// never watches `profileProvider` (a profile-presentation symbol); this
/// provider is the sole surface through which the settings feature reads the
/// current privacy, satisfying the cross-feature domain-only isolation rule.
///
/// Returns null for every error so Riverpod never auto-retries this provider,
/// matching `profileProvider` and the other authed reads: a Left surfaces as
/// AsyncError immediately rather than re-issuing the privileged owner-profile
/// read behind the error UI.
Duration? _noRetry(int retryCount, Object error) => null;

/// Throws the [Failure] on a Left so the AsyncValue carries it as an error —
/// matching the fold convention used by `profileProvider` so `AsyncValueWidget`
/// can surface the error through the same affordance.
@Riverpod(retry: _noRetry)
Future<ProfilePrivacy> settingsCurrentPrivacy(Ref ref) async {
  final repo = ref.watch(profileRepositoryProvider);
  final result = await repo.fetchMyProfile();
  return result.fold((failure) => throw failure, (p) => p.privacy);
}
