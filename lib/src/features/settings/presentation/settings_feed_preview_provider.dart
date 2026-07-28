import 'package:equatable/equatable.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../connections/domain/connection.dart';
import '../../connections/domain/connections_providers.dart';
import '../../profile/domain/profile_providers.dart';

part 'settings_feed_preview_provider.g.dart';

/// What the feed-preview control needs to render: the platform currently
/// pinned as the discovery preview (null = let the feed pick), and the
/// platforms the owner could pin.
final class FeedPreviewOptions extends Equatable {
  const FeedPreviewOptions({required this.selected, required this.linked});

  final Platform? selected;
  final List<Platform> linked;

  /// A pinned platform stays offered even once unlinked, so the control shows
  /// what is actually stored rather than silently reading as "automatic".
  List<Platform> get selectable => [
    ...linked,
    if (selected != null && !linked.contains(selected)) selected!,
  ];

  @override
  List<Object?> get props => [selected, linked];
}

/// Returns null for every error so Riverpod never auto-retries this provider,
/// matching the other authed reads: a Left surfaces as AsyncError immediately
/// rather than re-issuing privileged calls behind the error UI.
Duration? _noRetry(int retryCount, Object error) => null;

/// Settings-owned read seam for the feed-preview control.
///
/// Depends only on domain providers, never on a profile-presentation symbol —
/// the same cross-feature isolation the privacy seam keeps. Both reads are
/// folded into one value so the screen renders one async section: two would
/// show two spinners and two retry buttons for one control.
@Riverpod(retry: _noRetry)
Future<FeedPreviewOptions> settingsFeedPreview(Ref ref) async {
  final profileRepo = ref.watch(profileRepositoryProvider);
  final connectionsRepo = ref.watch(connectionsRepositoryProvider);

  final profileResult = await profileRepo.fetchMyProfile();
  final selected = profileResult.fold(
    (failure) => throw failure,
    (profile) => profile.featuredPlatform,
  );

  final connectionsResult = await connectionsRepo.fetchMyConnections();
  final linked = connectionsResult.fold(
    (failure) => throw failure,
    (connections) => [for (final c in connections) c.platform],
  );

  return FeedPreviewOptions(selected: selected, linked: linked);
}
