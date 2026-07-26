import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/core.dart';
import '../../../connections/domain/game_card.dart';
import '../../domain/completionist_value_resolver.dart';
import '../../domain/profile_archetype.dart';
import '../../domain/profile_widget.dart';
import '../personalization_card_shell.dart';
import '../personalization_motifs.dart';
import '../profile_owner_cards_provider.dart';
import 'card_data.dart';
import 'card_key.dart';

/// Achievement Grid archetype (spec §7, "Completionist" variant): the bound
/// platform's perfect-games count as a letter shelf. Full only. Folds the card
/// through the pure [resolveCompletionist]: a leading and trailing muted diamond
/// bracket one accent letter tile per perfect-game shelf entry (capped), with the
/// perfect count (games-owned too, when present) in the datum. A null resolve →
/// just the two diamonds, no stats — the no-data state stays a designed card,
/// never a fallback. A resolved `games_perfect` of 0 is honest data and
/// renders "0".
class AchievementGridCard extends ConsumerWidget {
  const AchievementGridCard({super.key, required this.widget, this.cardSource});

  final ProfileWidget widget;
  final CardSource? cardSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = PersonalizationTheme.of(context);
    final platform = widget.platform;
    final card = platform == null
        ? null
        : resolveCard(ref, cardSource, platform);
    final resolved = resolveCompletionist(card);

    final tiles = <Widget>[
      _LetterTile(
        tileKey: Key('personalizationAchievementMisc_${widget.id}_0'),
        palette: palette,
      ),
    ];
    var i = 0;
    for (final entry in resolved?.shelf ?? const <PerfectShowcaseEntry>[]) {
      if (i >= PersonalizationLayout.achievementGridLetterCap) break;
      final glyph = letterGlyph(entry.title);
      if (glyph == null) continue;
      tiles.add(
        _LetterTile(
          tileKey: achievementLetterKey(widget.id, i),
          glyph: glyph,
          palette: palette,
          imageUrl: entry.heroImage,
        ),
      );
      i++;
    }
    tiles.add(
      _LetterTile(
        tileKey: Key('personalizationAchievementMisc_${widget.id}_1'),
        palette: palette,
      ),
    );

    return PersonalizationCardShell(
      key: personalizationCardKey(widget.id),
      archetype: ProfileArchetype.achievementGrid,
      size: ProfileCardSize.full,
      framedContent: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: tiles,
        ),
      ),
      stats: completionistStats(resolved, l10n),
    );
  }
}

/// An Achievement Grid tile (mockup `.letter`): a `surface2` square with a `line`
/// border holding the accent-tinted perfect-game initial, or — with no [glyph] —
/// the muted diamond that brackets the shelf. Every tone reads from the palette,
/// so a theme swap re-tints it.
class _LetterTile extends StatelessWidget {
  const _LetterTile({
    required this.tileKey,
    required this.palette,
    this.glyph,
    this.imageUrl,
  });

  final Key tileKey;
  final PersonalizationPalette palette;

  /// The perfect-game's initial; null renders the bracketing diamond instead.
  final String? glyph;

  /// The perfect-game's cover; null → the themed letter glyph (the bracketing
  /// diamonds never carry art).
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final letter = glyph;
    return Container(
      key: tileKey,
      width: PersonalizationLayout.letterTileSize,
      height: PersonalizationLayout.letterTileSize,
      decoration: BoxDecoration(
        color: palette.surface2,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      // The line border stays visible over a loaded cover.
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
            child: letter == null
                ? PersonalizationDiamond(
                    color: palette.muted,
                    size: AppSpacing.smMd,
                  )
                : Text(
                    letter,
                    style: textTheme.titleMedium?.copyWith(
                      color: palette.accent,
                      fontWeight: AppTypography.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
