import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../connections/domain/connection.dart';
import '../../connections/domain/game_card.dart';
import '../../connections/domain/platform_descriptor.dart';
import '../domain/profile.dart';
import '../domain/profile_header_resolver.dart';
import 'cards/card_data.dart';
import 'personalization_card_shell.dart';
import 'profile_owner_cards_provider.dart';

/// Stable keys for the header's parts, so a test can assert each is the real
/// one rather than a stand-in.
const Key kProfileHeaderCoverKey = Key('profileHeaderCover');
const Key kProfileHeaderAvatarKey = Key('profileHeaderAvatar');
const Key kProfileHeaderNameKey = Key('profileHeaderName');
const Key kProfileHeaderMarksKey = Key('profileHeaderMarks');

/// The profile header — the answer to "who am I", and the one surface on the
/// profile that is not a card: it carries no number, and it cannot be moved,
/// paired or removed.
///
/// A wide, shallow cover with the identity beneath it and the avatar straddling
/// the seam. Deliberately short: the header frames the profile, the cards are
/// the profile, and every pixel spent here is one the first card does not get.
///
/// The marks are text, never a logo or a brand color: they say which accounts
/// stand behind the profile without turning the header into a sponsor wall.
class ProfileHeader extends ConsumerWidget {
  const ProfileHeader({
    super.key,
    required this.profile,
    required this.columnWidth,
    this.cardSource,
  });

  final Profile profile;

  /// The column the header spans; the cover height and the type scale derive
  /// from it.
  final double columnWidth;

  /// Where each platform's card resolves from. Null → the owner's own card; the
  /// router injects the public source for the visitor render.
  final CardSource? cardSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = PersonalizationTheme.of(context);
    final cards = <Platform, GameCard?>{
      for (final platform in Platform.values)
        platform: resolveCard(ref, cardSource, platform),
    };
    final header = resolveProfileHeader(
      cards,
      chosen: profile.headerPlatform,
      featured: profile.featuredPlatform,
    );
    final avatarSize = fluidByWidth(
      columnWidth,
      min: PersonalizationLayout.avatarMinSize,
      max: PersonalizationLayout.avatarSize,
    );
    final rise = avatarSize * PersonalizationLayout.avatarOverlap;

    return ClipRRect(
      borderRadius: BorderRadius.circular(palette.radius),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Cover(imageUrl: header.art),
              ColoredBox(
                color: palette.surface,
                // The identity clears the part of the avatar hanging into it.
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    rise + AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: _Identity(
                    profile: profile,
                    platforms: header.platforms,
                    columnWidth: columnWidth,
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: AppSpacing.md,
            // Straddles the seam rather than sitting under it, which is what
            // ties the two halves into one block.
            top: columnWidth / PersonalizationLayout.coverAspect - rise,
            child: _Avatar(
              url: profile.avatarUrl,
              word: profileHeaderName(profile),
              size: avatarSize,
            ),
          ),
        ],
      ),
    );
  }
}

/// The display name, falling back to the handle when it is empty.
String profileHeaderName(Profile profile) =>
    profile.displayName.isNotEmpty ? profile.displayName : profile.username;

/// The cover: real art cropped to a wide, shallow frame, or the theme's own
/// fill for a profile with nothing linked. Cropping is the point — a cover
/// takes the middle of whatever it is given rather than letterboxing it.
class _Cover extends StatelessWidget {
  const _Cover({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final palette = PersonalizationTheme.of(context);
    return AspectRatio(
      key: kProfileHeaderCoverKey,
      aspectRatio: PersonalizationLayout.coverAspect,
      child: personalizationArtOrPlaceholder(
        imageUrl: imageUrl,
        placeholder: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [palette.artC, palette.artA, palette.artB],
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Name, handle, platform marks and bio, on the theme's own surface. On solid
/// ground rather than over art, so none of it needs a scrim to stay legible.
class _Identity extends StatelessWidget {
  const _Identity({
    required this.profile,
    required this.platforms,
    required this.columnWidth,
  });

  final Profile profile;
  final List<Platform> platforms;
  final double columnWidth;

  @override
  Widget build(BuildContext context) {
    final palette = PersonalizationTheme.of(context);
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final bio = profile.bio;
    // Brand names, so not localized. One line rather than a row of chips: seven
    // outlined pills read as clutter beside a name, and the line ellipsizes
    // cleanly where chips would wrap and grow the header.
    final marks = platforms
        .map((platform) => platformDescriptors[platform]?.shortName ?? '')
        .where((mark) => mark.isNotEmpty)
        .join(' · ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profileHeaderName(profile),
          key: kProfileHeaderNameKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.headlineSmall?.copyWith(
            color: palette.text,
            fontWeight: AppTypography.bold,
            letterSpacing: PersonalizationLayout.headerNameTracking,
            fontSize: fluidByWidth(
              columnWidth,
              min: PersonalizationLayout.headerNameMinSize,
              max: PersonalizationLayout.headerNameMaxSize,
            ),
          ),
        ),
        Text(
          l10n.profileHandle(profile.username),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelMedium?.copyWith(
            color: palette.accent,
            fontWeight: AppTypography.semiBold,
          ),
        ),
        if (marks.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            marks.toUpperCase(),
            key: kProfileHeaderMarksKey,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(
              color: palette.muted,
              letterSpacing: PersonalizationLayout.tagTracking,
            ),
          ),
        ],
        if (bio != null && bio.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            bio,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(color: palette.muted),
          ),
        ],
      ],
    );
  }
}

/// The owner's avatar, falling back to a monogram on the theme's art tones for
/// a profile that has none — and while the image loads, and if it fails. The
/// surface-colored ring is what separates it from the art it straddles.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.word, required this.size});

  final String? url;
  final String word;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = PersonalizationTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final initial = word.isEmpty ? '?' : word.substring(0, 1).toUpperCase();

    return Container(
      key: kProfileHeaderAvatarKey,
      padding: const EdgeInsets.all(AppSpacing.hairline),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg + AppSpacing.hairline),
      ),
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [palette.artA, palette.artC]),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: palette.accent, width: AppSpacing.hairline),
        ),
        child: personalizationArtOrPlaceholder(
          imageUrl: url,
          placeholder: Center(
            child: Text(
              initial,
              style: textTheme.titleLarge?.copyWith(
                color: PersonalizationArtColors.onArt,
                fontWeight: AppTypography.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
