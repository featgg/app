import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../profile/domain/profile.dart';
import 'public_profile_provider.dart';

/// Builds the read-only visitor render of a user's `profile_widgets` arrangement
/// for [userId]. Injected at the composition root (the router) so this feature's
/// presentation stays decoupled from the profile feature that owns the widgets
/// view and the card renderer.
typedef PublicWidgetsBuilder = Widget Function(String userId);

/// Displays any user's public profile in read-only visitor mode.
/// No edit affordance and no privacy indicator — the data is public by
/// definition (RLS returns no row to a non-owner for private profiles).
class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({
    super.key,
    required this.userId,
    required this.widgetsBuilder,
  });

  final String userId;
  final PublicWidgetsBuilder widgetsBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(publicProfileProvider(userId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.publicProfileTitle)),
      body: SafeArea(
        child: AsyncValueWidget<Profile?>(
          value: state,
          onRetry: () => ref.invalidate(publicProfileProvider(userId)),
          loading: const ProfileSkeleton(),
          data: (profile) => profile == null
              ? const _UnavailableState()
              : _PublicProfileContent(
                  userId: userId,
                  profile: profile,
                  widgetsBuilder: widgetsBuilder,
                ),
        ),
      ),
    );
  }
}

class _PublicProfileContent extends StatelessWidget {
  const _PublicProfileContent({
    required this.userId,
    required this.profile,
    required this.widgetsBuilder,
  });

  final String userId;
  final Profile profile;
  final PublicWidgetsBuilder widgetsBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              // Top-anchored so the avatar/identity block stays put while the
              // widgets section settles — vertical centering made the whole page
              // jump as content loaded in.
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _Avatar(avatarUrl: profile.avatarUrl, l10n: l10n),
                const SizedBox(height: AppSpacing.md),
                Text(
                  profile.displayName,
                  style: textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.profileHandle(profile.username),
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  (profile.bio?.isNotEmpty == true)
                      ? profile.bio!
                      : l10n.profileBioEmpty,
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                // The visitor render is driven entirely by the owner's saved
                // widget arrangement, assembled at the composition root.
                widgetsBuilder(userId),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnavailableState extends StatelessWidget {
  const _UnavailableState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          l10n.publicProfileUnavailable,
          key: const Key('publicProfileUnavailable'),
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.avatarUrl, required this.l10n});

  final String? avatarUrl;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const size = AppSpacing.xl * 3;

    if (avatarUrl != null) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          fadeInDuration: Duration.zero,
          placeholderFadeInDuration: Duration.zero,
          placeholder: (context, url) => _iconPlaceholder(colorScheme, size),
          errorWidget: (context, url, error) =>
              _iconPlaceholder(colorScheme, size),
          imageBuilder: (_, imageProvider) => Semantics(
            label: l10n.profileAvatarLabel,
            image: true,
            child: Image(
              image: imageProvider,
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: l10n.profileAvatarLabel,
      child: _iconPlaceholder(colorScheme, size),
    );
  }

  Widget _iconPlaceholder(ColorScheme colorScheme, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.surfaceContainerHighest,
      ),
      child: Icon(
        Icons.person,
        size: size / 2,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}
