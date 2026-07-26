import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../domain/profile_archetype.dart';
import 'personalization_motifs.dart';

/// Renders real platform art at [imageUrl] over the procedural [placeholder], or
/// the placeholder alone when the url is null. Loading and error both fall back
/// to the placeholder, so a payload never yields a broken-image glyph (feed
/// image rules). The single place a personalization card wires art, so every
/// card's null / loading / error fill is identical.
Widget personalizationArtOrPlaceholder({
  required String? imageUrl,
  required Widget placeholder,
}) {
  final url = imageUrl;
  if (url == null) return placeholder;
  return CachedNetworkImage(
    imageUrl: url,
    fit: BoxFit.cover,
    placeholder: (_, _) => placeholder,
    errorWidget: (_, _, _) => placeholder,
  );
}

/// One datum stat entry: a big number with a small uppercase label. Both are
/// already-formatted display strings; the shell never interprets them.
class PersonalizationStat {
  const PersonalizationStat({required this.value, required this.label});

  final String value;
  final String label;
}

/// The two-format card chassis. The card supplies its archetype and whatever art
/// its subject resolved to; the format comes from the registry, so no card
/// carries a format branch. Nothing renders above the fill: no title, no
/// platform tag, no date. Every color and size reads from
/// [PersonalizationTheme] / the personalization tokens, so a theme swap re-tints
/// the whole card.
class PersonalizationCardShell extends StatelessWidget {
  const PersonalizationCardShell({
    super.key,
    required this.archetype,
    required this.size,
    this.art,
    this.motifContent,
    this.subject,
    this.detail,
    this.stats = const [],
  });

  final ProfileArchetype archetype;

  /// Selects the designed aspect; a card's height is a function of its width.
  final ProfileCardSize size;

  /// The subject's real art. Null — or a url that fails to load — renders the
  /// framed format over the archetype's motif.
  final String? art;

  /// The archetype's designed content, drawn over the motif field (the orb
  /// shelf, the letter shelf, the platform chips). Framed cards only.
  final Widget? motifContent;

  /// What the number is about, and its secondary line.
  final String? subject;
  final String? detail;

  final List<PersonalizationStat> stats;

  @override
  Widget build(BuildContext context) {
    final palette = PersonalizationTheme.of(context);
    final format = renderedCardFormat(archetype, hasArt: art != null);
    final motifField = PersonalizationMotifField(motif: cardMotif(archetype));
    final datum = PersonalizationDatum(
      format: format,
      subject: subject,
      detail: detail,
      stats: stats,
    );
    final content = motifContent;

    return ClipRRect(
      borderRadius: BorderRadius.circular(palette.radius),
      // The only child reporting an intrinsic height, so a card's height is
      // known without loading an image; under a tight height (a stretched pair
      // slot) it takes that height instead and the fill covers it.
      child: AspectRatio(
        aspectRatio: size == ProfileCardSize.full
            ? PersonalizationLayout.cardFullAspect
            : PersonalizationLayout.cardHalfAspect,
        child: format == ProfileCardFormat.bleed
            ? Stack(
                fit: StackFit.expand,
                children: [
                  personalizationArtOrPlaceholder(
                    imageUrl: art,
                    placeholder: motifField,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.center,
                        colors: [
                          PersonalizationArtColors.heroScrim,
                          PersonalizationArtColors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Positioned(left: 0, right: 0, bottom: 0, child: datum),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  motifField,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: content == null
                            ? const SizedBox.expand()
                            : Padding(
                                padding: const EdgeInsets.all(AppSpacing.smMd),
                                child: content,
                              ),
                      ),
                      datum,
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

/// The card's datum zone. Bleed draws it over the art with a legibility shadow;
/// framed draws it in its own band, closed by the single line that is the only
/// border anywhere on the card. Public so tests can assert every card's stats
/// render inside it (the "proof" zone), never loose in the content.
class PersonalizationDatum extends StatelessWidget {
  const PersonalizationDatum({
    super.key,
    required this.format,
    this.subject,
    this.detail,
    this.stats = const [],
  });

  final ProfileCardFormat format;
  final String? subject;
  final String? detail;
  final List<PersonalizationStat> stats;

  @override
  Widget build(BuildContext context) {
    final palette = PersonalizationTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final onArt = format == ProfileCardFormat.bleed;
    // Muted grey is not legible over light art even under the bottom gradient,
    // so both lines take the on-art tone there.
    final primary = onArt ? PersonalizationArtColors.onArt : palette.text;
    final secondary = onArt ? PersonalizationArtColors.onArt : palette.muted;
    final shadows = onArt ? PersonalizationArtText.shadows : null;
    final subjectText = subject;
    final detailText = detail;

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (subjectText != null)
          Text(
            subjectText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall?.copyWith(
              color: primary,
              fontWeight: AppTypography.bold,
              shadows: shadows,
            ),
          ),
        if (detailText != null)
          Text(
            detailText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(
              color: secondary,
              shadows: shadows,
            ),
          ),
        if (stats.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final stat in stats)
                // Loose so an entry sizes to content when it fits, but stays
                // width-bounded on a narrow half card so its label ellipsizes
                // instead of forcing the Row past the card edge.
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
                            color: primary,
                            fontWeight: AppTypography.bold,
                            shadows: shadows,
                          ),
                        ),
                        Text(
                          stat.label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            color: secondary,
                            letterSpacing: PersonalizationLayout.labelTracking,
                            shadows: shadows,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
      ],
    );

    const padding = EdgeInsets.symmetric(
      horizontal: AppSpacing.smMd,
      vertical: AppSpacing.sm,
    );

    if (onArt) return Padding(padding: padding, child: body);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(
          bottom: BorderSide(
            color: palette.line,
            width: PersonalizationLayout.borderWidth,
          ),
        ),
      ),
      child: body,
    );
  }
}
