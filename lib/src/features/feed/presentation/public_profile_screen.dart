import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../profile/domain/profile.dart';
import 'public_profile_provider.dart';

/// Builds the profile render for [profile]. Injected at the composition root
/// (the router) so this feature's presentation stays decoupled from the
/// profile feature that owns the render and the card vocabulary.
typedef PersonalizationBuilder =
    Widget Function(Profile profile, String userId);

/// The chrome colors a profile's own theme calls for. Injected the same way
/// and for the same reason: the palette belongs to the profile feature, but
/// the app bar above the render is this screen's to build, and a default-themed
/// bar over a themed page reads as two pages stitched together.
typedef ProfileChromeBuilder =
    ({Color background, Color foreground}) Function(Profile profile);

/// Displays any user's public profile in read-only visitor mode.
/// No edit affordance and no privacy indicator — the data is public by
/// definition (RLS returns no row to a non-owner for private profiles).
class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({
    super.key,
    required this.userId,
    required this.personalizationBuilder,
    required this.chromeBuilder,
  });

  final String userId;

  /// Renders the profile. Injected by the router so this feature stays
  /// decoupled from the profile feature's presentation.
  final PersonalizationBuilder personalizationBuilder;

  /// Supplies the app bar's colors from the rendered profile's theme.
  final ProfileChromeBuilder chromeBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(publicProfileProvider(userId));

    // Null until the profile resolves, and for a profile that resolves to
    // nothing: neither has a theme to take colors from, so the bar keeps the
    // app's own until there is a page under it to match.
    final profile = state.hasValue ? state.value : null;
    final chrome = profile == null ? null : chromeBuilder(profile);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.publicProfileTitle),
        backgroundColor: chrome?.background,
        foregroundColor: chrome?.foreground,
      ),
      body: SafeArea(
        child: AsyncValueWidget<Profile?>(
          value: state,
          onRetry: () => ref.invalidate(publicProfileProvider(userId)),
          loading: const ProfileSkeleton(),
          // One render for every visitor profile: a profile with no saved
          // arrangement shows its cards in the order the editor would seed,
          // rather than falling to a different-looking page.
          data: (profile) => profile == null
              ? const _UnavailableState()
              : personalizationBuilder(profile, userId),
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
