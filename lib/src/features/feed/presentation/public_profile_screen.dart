import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../connections/domain/connection.dart';
import '../../connections/domain/game_card.dart';
import '../../profile/domain/profile.dart';
import 'public_profile_provider.dart';

/// Builds the full card view for a loaded public [GameCard]. Injected at the
/// composition root (the router) so this feature's presentation stays
/// decoupled from the card renderer's owning feature.
typedef PublicCardBuilder = Widget Function(GameCard card);

/// Displays any user's public profile in read-only visitor mode.
/// No edit affordance and no privacy indicator — the data is public by
/// definition (RLS returns no row to a non-owner for private profiles).
class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({
    super.key,
    required this.userId,
    required this.cardBuilder,
  });

  final String userId;
  final PublicCardBuilder cardBuilder;

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
                  cardBuilder: cardBuilder,
                ),
        ),
      ),
    );
  }
}

class _PublicProfileContent extends ConsumerWidget {
  const _PublicProfileContent({
    required this.userId,
    required this.profile,
    required this.cardBuilder,
  });

  final String userId;
  final Profile profile;
  final PublicCardBuilder cardBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // One watch per platform feeds both the per-card rendering and the
    // all-null empty-state predicate.
    final cardStates = {
      for (final p in Platform.values)
        p: ref.watch(publicCardProvider(userId, p)),
    };

    // Section is ready once every read has settled (data or error — not loading).
    // This prevents N independent spinners from appearing while reads are in
    // flight and ensures the cards render together.
    final allSettled = cardStates.values.every((s) => s is! AsyncLoading);

    final allResolved = cardStates.values.every((s) => s is AsyncData);
    final allNull =
        allResolved &&
        cardStates.values.every((s) => (s as AsyncData).value == null);

    // Platforms that will render visible content (non-null data or an error
    // tile). Card-less platforms (AsyncData(null)) contribute no padding.
    final renderablePlatforms = Platform.values
        .where(
          (p) =>
              cardStates[p] is AsyncError ||
              (cardStates[p] is AsyncData &&
                  (cardStates[p] as AsyncData).value != null),
        )
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              // Top-anchored so the avatar/identity block stays put while the
              // cards section settles — vertical centering made the whole page
              // jump as the cards loaded in.
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
                if (!allSettled)
                  // Card-shaped placeholders while any platform read is still
                  // loading: they occupy realistic space, so the page does not
                  // reflow when the real cards resolve.
                  const ProfileCardsSkeleton()
                else if (allNull)
                  Text(
                    l10n.publicProfileNoCards,
                    key: const Key('publicProfileNoCards'),
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  )
                else
                  // Renderable platforms carry bottom padding; card-less
                  // platforms (null data) get none so there are no phantom gaps.
                  ...Platform.values.map((p) {
                    final isRenderable = renderablePlatforms.contains(p);
                    final widget = AsyncValueWidget<GameCard?>(
                      key: Key('publicCard_${p.name}'),
                      value: cardStates[p]!,
                      onRetry: () =>
                          ref.invalidate(publicCardProvider(userId, p)),
                      data: (card) => card == null
                          ? const SizedBox.shrink()
                          : cardBuilder(card),
                    );
                    return isRenderable
                        ? Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: widget,
                          )
                        : widget;
                  }),
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
