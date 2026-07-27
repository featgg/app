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
import 'personalization_hero_canvas.dart';
import 'profile_owner_cards_provider.dart';

/// Stable keys for the header's identity, so a test can assert each part is the
/// real one rather than the stand-in it used to be.
const Key kProfileHeaderAvatarKey = Key('profileHeaderAvatar');
const Key kProfileHeaderNameKey = Key('profileHeaderName');
const Key kProfileHeaderMarksKey = Key('profileHeaderMarks');

/// The profile header — the answer to "who am I", and the one surface on the
/// profile that is not a card: it carries no number, and it cannot be moved,
/// paired or removed.
///
/// Art, avatar, name and the marks of every linked platform read as one block.
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

  /// The column the header spans; the art budget and the type scale derive
  /// from it.
  final double columnWidth;

  /// Where each platform's card resolves from. Null → the owner's own card; the
  /// router injects the public source for the visitor render.
  final CardSource? cardSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = <Platform, GameCard?>{
      for (final platform in Platform.values)
        platform: resolveCard(ref, cardSource, platform),
    };
    final header = resolveProfileHeader(
      cards,
      chosen: profile.headerPlatform,
      featured: profile.featuredPlatform,
    );

    return PersonalizationHeroCanvas(
      columnWidth: columnWidth,
      imageUrl: header.art,
      child: _Identity(
        profile: profile,
        platforms: header.platforms,
        columnWidth: columnWidth,
      ),
    );
  }
}

/// The display name, falling back to the handle when it is empty.
String profileHeaderName(Profile profile) =>
    profile.displayName.isNotEmpty ? profile.displayName : profile.username;

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
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final bio = profile.bio;
    // Brand names, so not localized. Joined into one line rather than a row of
    // chips: over art, seven outlined pills read as clutter competing with the
    // name, and the line ellipsizes cleanly where the chips would wrap.
    final marks = platforms
        .map((platform) => platformDescriptors[platform]?.shortName ?? '')
        .where((mark) => mark.isNotEmpty)
        .join(' · ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatar(
          url: profile.avatarUrl,
          word: profileHeaderName(profile),
          size: fluidByWidth(
            columnWidth,
            min: PersonalizationLayout.avatarMinSize,
            max: PersonalizationLayout.avatarSize,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          profileHeaderName(profile).toUpperCase(),
          key: kProfileHeaderNameKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.headlineMedium?.copyWith(
            color: PersonalizationArtColors.onArt,
            fontWeight: AppTypography.bold,
            letterSpacing: PersonalizationLayout.heroWordTracking,
            fontSize: fluidByWidth(
              columnWidth,
              min: PersonalizationLayout.heroWordMinSize,
              max: PersonalizationLayout.heroWordMaxSize,
            ),
            shadows: PersonalizationArtText.shadows,
          ),
        ),
        Text(
          l10n.profileHandle(profile.username),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelMedium?.copyWith(
            color: PersonalizationArtColors.onArt,
            fontWeight: AppTypography.semiBold,
            shadows: PersonalizationArtText.shadows,
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
              color: PersonalizationArtColors.onArt,
              letterSpacing: PersonalizationLayout.tagTracking,
              shadows: PersonalizationArtText.shadows,
            ),
          ),
        ],
        if (bio != null && bio.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            bio,
            // One line here: the header's job is identity, and the art behind it
            // is the budget every extra line spends.
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: PersonalizationArtColors.onArt,
              shadows: PersonalizationArtText.shadows,
            ),
          ),
        ],
      ],
    );
  }
}

/// The owner's avatar, falling back to a monogram on the theme's art tones for a
/// profile that has none — and while the image loads, and if it fails.
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
            style: textTheme.headlineSmall?.copyWith(
              color: PersonalizationArtColors.onArt,
              fontWeight: AppTypography.bold,
            ),
          ),
        ),
      ),
    );
  }
}
