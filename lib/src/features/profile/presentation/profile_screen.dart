import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../core/error/failure.dart';
import '../../connections/domain/game_card.dart';
import '../domain/profile.dart';
import '../domain/profile_widget.dart';
import 'owner_profile_personalization.dart';
import 'profile_provider.dart';
import 'profile_widgets_controller.dart';
import 'profile_widgets_grid.dart';
import 'profile_widgets_provider.dart';
import 'showcase_picker.dart';

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
    // Observe the widget-mutation controller here: the screen outlives every
    // grid tile and the add button, so this listener keeps the autoDispose
    // controller alive across an in-flight mutation (its post-await invalidate
    // fires and the grid refreshes) and surfaces a failure as a SnackBar.
    ref.listen<AsyncValue<void>>(profileWidgetsControllerProvider, (
      previous,
      next,
    ) {
      if (!context.mounted || !next.hasError) return;
      final error = next.error!;
      final msg = error is Failure
          ? error.localizedMessage(l10n)
          : l10n.errorUnexpected;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            key: const Key('profileWidgetsErrorSnackBar'),
            content: Text(msg),
          ),
        );
    });
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
          // A composed layout routes to the personalization render + editor; an
          // empty layout keeps the legacy owner grid.
          data: (profile) => profile.layout.isEmpty
              ? _ProfileContent(profile: profile, cardBuilder: cardBuilder)
              : OwnerProfilePersonalization(profile: profile),
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

    final widgetsState = ref.watch(ownerProfileWidgetsProvider);

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
                // One add entry point, shown once the widgets read has a value:
                // the read supplies the position math (no collision on the
                // unique column). While it is loading or errored, Add is absent.
                if (widgetsState.hasValue)
                  _AddCardButton(existing: widgetsState.value!),
                const SizedBox(height: AppSpacing.md),
                AsyncValueWidget<List<ProfileWidget>>(
                  value: widgetsState,
                  onRetry: () => ref.invalidate(ownerProfileWidgetsProvider),
                  loading: const ProfileCardsSkeleton(),
                  // Distinguish "no widgets at all" (the add-one hint) from
                  // "all widgets hidden" (the grid still renders them dimmed
                  // with a Show action), so the hint is never misleading.
                  data: (widgets) => widgets.isEmpty
                      ? Text(
                          l10n.profileWidgetsEmpty,
                          key: const Key('profileWidgetsEmpty'),
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        )
                      : ProfileWidgetsGrid(
                          key: const Key('profileWidgetsGrid'),
                          widgets: widgets,
                          cardBuilder: cardBuilder,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The single add-card entry point on the owner's profile. Opens the visual
/// game picker (a sheet of the connected account's library art). The backend
/// stays authoritative on the ≤50-widget cap and `position` uniqueness — a
/// rejected insert surfaces through the controller's error channel and the read
/// reconciles on invalidate. Shown only once the widgets read has a value, so
/// the sheet can compute the insert position from the current arrangement.
class _AddCardButton extends StatelessWidget {
  const _AddCardButton({required this.existing});

  final List<ProfileWidget> existing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return InkWell(
      key: const Key('profileAddCardButton'),
      onTap: () => showShowcasePicker(context, existing: existing),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add),
          const SizedBox(width: AppSpacing.xs),
          Text(l10n.profileAddCard),
        ],
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
