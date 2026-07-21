import 'package:flutter/material.dart';

import '../../../core/core.dart';

/// One stat-footer entry: a big number with a small uppercase label
/// (`docs/personalization/spec.md` §6). Both are already-formatted display
/// strings; the shell never interprets them.
class PersonalizationStat {
  const PersonalizationStat({required this.value, required this.label});

  final String value;
  final String label;
}

/// The three-zone card shell (spec §6): title bar (card title left, accent
/// platform tag right), a content slot, and an optional stat footer of 2–4 big
/// numbers. Every color and size reads from [PersonalizationTheme] / the
/// personalization tokens, so a theme swap re-tints the whole card.
class CardShell extends StatelessWidget {
  const CardShell({
    super.key,
    required this.title,
    required this.platformTag,
    required this.content,
    this.stats = const [],
  });

  final String title;

  /// The platform label shown as the accent tag (proper noun; not localized).
  final String platformTag;

  final Widget content;

  /// 0 (pure-art cards) to 4 stat entries; rendered in the footer zone.
  final List<PersonalizationStat> stats;

  @override
  Widget build(BuildContext context) {
    final palette = PersonalizationTheme.of(context);
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(
          color: palette.line,
          width: PersonalizationLayout.borderWidth,
        ),
        borderRadius: BorderRadius.circular(palette.radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(palette.radius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TitleBar(
              title: title,
              platformTag: platformTag,
              palette: palette,
              textTheme: textTheme,
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.smMd),
              child: content,
            ),
            if (stats.isNotEmpty)
              PersonalizationStatFooter(stats: stats, palette: palette),
          ],
        ),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.title,
    required this.platformTag,
    required this.palette,
    required this.textTheme,
  });

  final String title;
  final String platformTag;
  final PersonalizationPalette palette;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smMd,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: palette.line,
            width: PersonalizationLayout.borderWidth,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelLarge?.copyWith(
                color: palette.text,
                fontWeight: AppTypography.medium,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Bounded and right-aligned: a short tag still hugs the right edge, a
          // long one ellipsizes within its half instead of overflowing the Row.
          Expanded(
            child: Text(
              platformTag.toUpperCase(),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(
                color: palette.accent,
                fontWeight: AppTypography.semiBold,
                letterSpacing: PersonalizationLayout.tagTracking,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The stat-footer zone (spec §6). Public so tests can assert every card's
/// stats render inside it (the "proof" zone), never loose in the content.
class PersonalizationStatFooter extends StatelessWidget {
  const PersonalizationStatFooter({
    super.key,
    required this.stats,
    required this.palette,
  });

  final List<PersonalizationStat> stats;
  final PersonalizationPalette palette;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smMd,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: palette.line,
            width: PersonalizationLayout.borderWidth,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final stat in stats)
            // Loose so an entry sizes to content when it fits, but stays
            // width-bounded on a narrow half card so its label ellipsizes
            // instead of forcing the footer Row past the card edge.
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        color: palette.text,
                        fontWeight: AppTypography.bold,
                      ),
                    ),
                    Text(
                      stat.label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        color: palette.muted,
                        letterSpacing: PersonalizationLayout.labelTracking,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A neutral token-gradient placeholder for a card's content zone: the personalization art
/// is a theme gradient, never a bundled asset, so the public repo stays
/// binary-free. The bottom paint is the solid mid-tone [PersonalizationPalette.artB]
/// (spec §8: never a gradient that can fall to black).
class PersonalizationArtBox extends StatelessWidget {
  const PersonalizationArtBox({super.key, required this.aspectRatio});

  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final palette = PersonalizationTheme.of(context);

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette.artC, palette.artA, palette.artB],
          ),
        ),
      ),
    );
  }
}
