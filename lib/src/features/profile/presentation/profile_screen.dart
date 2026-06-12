import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../connections/domain/connection.dart';
import '../../connections/domain/game_card.dart';
import '../domain/profile.dart';
import 'profile_owner_cards_provider.dart';
import 'profile_provider.dart';

/// Builds the full card view for the signed-in owner's [GameCard]. Injected at
/// the composition root (the router) so this feature's presentation stays
/// decoupled from the card renderer's owning feature.
typedef OwnerCardBuilder = Widget Function(GameCard card);

/// Displays the signed-in user's own profile.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.cardBuilder});

  final OwnerCardBuilder cardBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        actions: [
          IconButton(
            key: const Key('settingsEntryButton'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settingsTitle,
            onPressed: () async {
              // Refresh on return regardless of how settings was dismissed
              // (app-bar back, system back, or swipe). A typed pop result is
              // only delivered by the app-bar button, so relying on it left the
              // privacy indicator stale after a system/gesture back. The
              // refresh is cheap and shows no loading flash (the profile read
              // keeps its previous value on reload).
              await context.push('/settings');
              if (!context.mounted) return;
              ref.invalidate(profileProvider);
            },
          ), // Only show Edit when the profile has loaded; the action is defined
          // here so the AppBar is always present, but it is conditionally
          // populated from the data state below.
          if (state.hasValue)
            IconButton(
              key: const Key('profileEditButton'),
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.profileEdit,
              onPressed: () =>
                  context.push('/profile/edit', extra: state.value!),
            ),
        ],
      ),
      body: SafeArea(
        child: AsyncValueWidget<Profile>(
          value: state,
          onRetry: () => ref.invalidate(profileProvider),
          loading: const ProfileSkeleton(),
          data: (profile) =>
              _ProfileContent(profile: profile, cardBuilder: cardBuilder),
        ),
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.profile, required this.cardBuilder});

  final Profile profile;
  final OwnerCardBuilder cardBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // One watch per platform feeds both the per-card rendering and the
    // all-null empty-state predicate.
    final cardStates = {
      for (final p in Platform.values) p: ref.watch(ownerCardProvider(p)),
    };

    // Section is ready once every read has settled (data or error — not loading).
    // This prevents N independent spinners from appearing while reads are in
    // flight and ensures the header + cards render together.
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
                const SizedBox(height: AppSpacing.md),
                _PrivacyIndicator(privacy: profile.privacy, l10n: l10n),
                const SizedBox(height: AppSpacing.lg),
                if (!allSettled)
                  // Card-shaped placeholders while any platform read is still
                  // loading: they occupy realistic space, so the page does not
                  // reflow when the real cards resolve.
                  const ProfileCardsSkeleton()
                else if (allNull)
                  Text(
                    l10n.profileNoCardsYet,
                    key: const Key('profileNoCardsYet'),
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  )
                else ...[
                  Text(
                    l10n.profileCardsSectionTitle,
                    key: const Key('profileCardsSectionTitle'),
                    style: textTheme.titleSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Renderable platforms (non-null data or error) carry bottom
                  // padding; card-less platforms (null data) get none so there
                  // are no phantom gaps between real cards.
                  ...Platform.values.map((p) {
                    final isRenderable = renderablePlatforms.contains(p);
                    final widget = AsyncValueWidget<GameCard?>(
                      key: Key('ownerCard_${p.name}'),
                      value: cardStates[p]!,
                      onRetry: () => ref.invalidate(ownerCardProvider(p)),
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
              ],
            ),
          ),
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

class _PrivacyIndicator extends StatelessWidget {
  const _PrivacyIndicator({required this.privacy, required this.l10n});

  final ProfilePrivacy privacy;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isPrivate = privacy == ProfilePrivacy.private;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          key: Key(isPrivate ? 'privacyPrivateIcon' : 'privacyPublicIcon'),
          isPrivate ? Icons.lock_outline : Icons.public,
          size: AppSpacing.md,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          isPrivate ? l10n.profilePrivacyPrivate : l10n.profilePrivacyPublic,
          style: textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
