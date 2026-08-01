import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/core.dart';
import '../../domain/profile_archetype.dart';
import '../../domain/profile_widget.dart';
import '../../domain/rarest_achievement_value_resolver.dart';
import '../art_framing_control.dart';
import '../personalization_card_shell.dart';
import '../personalization_motifs.dart';
import '../profile_owner_cards_provider.dart';
import 'card_data.dart';
import 'card_key.dart';

/// Rarest Achievement archetype: "the hardest thing I have done" — the
/// achievement's name over the game's art, with how rare it is in the datum,
/// labelled by what the payload says the rarity is measured against. Folds the
/// bound platform's card through the pure [resolveRarestAchievement]; a payload
/// with no rarity renders a neutral no-data card, never the previous
/// achievement. With no game art the card degrades to framed and the
/// achievement's own badge becomes its content.
class RarestAchievementCard extends ConsumerWidget {
  const RarestAchievementCard({
    super.key,
    required this.widget,
    required this.size,
    this.cardSource,
  });

  final ProfileWidget widget;
  final ProfileCardSize size;
  final CardSource? cardSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = PersonalizationTheme.of(context);
    final platform = widget.platform;
    final card = platform == null
        ? null
        : resolveCard(ref, cardSource, platform);
    final resolved = resolveRarestAchievement(card);

    return PersonalizationCardShell(
      key: personalizationCardKey(widget.id),
      archetype: ProfileArchetype.rarestAchievement,
      size: size,
      art: resolved?.heroImage,
      framing: ArtFramingTarget(widgetId: widget.id, framing: widget.framing),
      subject: resolved?.name,
      // The game, not the platform: a named achievement in a named game places
      // the figure far more precisely than a platform tag would.
      detail: resolved?.game,
      // Null with nothing resolved, so the no-data state stays the bare themed
      // card the catalog already shows for an unresolved subject.
      framedContent: resolved == null
          ? null
          : Center(
              child: _AchievementBadge(
                badgeKey: Key('personalizationRarestBadge_${widget.id}'),
                palette: palette,
                imageUrl: resolved.iconImage,
              ),
            ),
      stats: rarestAchievementStats(resolved, l10n),
    );
  }
}

/// The achievement's own badge, drawn as the framed variant's content: a
/// `surface2` rounded square with a `line` hairline holding the published icon,
/// or the muted diamond when the payload publishes none. Every tone reads from
/// the palette, so a theme swap re-tints it.
class _AchievementBadge extends StatelessWidget {
  const _AchievementBadge({
    required this.badgeKey,
    required this.palette,
    this.imageUrl,
  });

  final Key badgeKey;
  final PersonalizationPalette palette;

  /// The achievement's badge url; null renders the placeholder glyph.
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: badgeKey,
      width: PersonalizationLayout.achievementBadgeSize,
      height: PersonalizationLayout.achievementBadgeSize,
      decoration: BoxDecoration(
        color: palette.surface2,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      // The line border stays visible over a loaded badge.
      foregroundDecoration: BoxDecoration(
        border: Border.all(
          color: palette.line,
          width: PersonalizationLayout.borderWidth,
        ),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: personalizationArtOrPlaceholder(
          imageUrl: imageUrl,
          placeholder: Center(
            child: PersonalizationDiamond(
              color: palette.accent,
              size: AppSpacing.md,
            ),
          ),
        ),
      ),
    );
  }
}
