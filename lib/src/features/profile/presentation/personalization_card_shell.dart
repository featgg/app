import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../domain/art_framing.dart';
import '../domain/profile_archetype.dart';
import 'art_framing_control.dart';

/// The ground a framed card sits on: the theme's own vertical fill, nothing
/// drawn over it. The bottom paint is the solid mid-tone, never a gradient that
/// can fall to black, so the card stays inside the theme.
class PersonalizationCardGround extends StatelessWidget {
  const PersonalizationCardGround({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = PersonalizationTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.artC, palette.artB],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// Renders real platform art at [imageUrl] over the procedural [placeholder], or
/// the placeholder alone when the url is null. Loading and error both fall back
/// to the placeholder, so a payload never yields a broken-image glyph (feed
/// image rules). The single place a personalization card wires art, so every
/// card's null / loading / error fill is identical.
Widget personalizationArtOrPlaceholder({
  required String? imageUrl,
  required Widget placeholder,
  ArtFraming framing = ArtFraming.center,
}) {
  final url = imageUrl;
  if (url == null) return placeholder;
  return CachedNetworkImage(
    imageUrl: url,
    fit: BoxFit.cover,
    // The framing decides which part of an oversized picture survives the crop.
    // The fit never changes with it, so panning can never shrink the art below
    // its frame and expose the ground behind it.
    alignment: Alignment(framing.x * 2 - 1, framing.y * 2 - 1),
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
    this.framing,
    this.framedContent,
    this.hero,
    this.subject,
    this.detail,
    this.stats = const [],
  });

  final ProfileArchetype archetype;

  /// Selects the designed aspect; a card's height is a function of its width.
  final ProfileCardSize size;

  /// The subject's real art. Null — or a url that fails to load — renders the
  /// framed format over the theme's ground.
  final String? art;

  /// How the owner framed [art], and which widget to write a new framing back
  /// to. Null on a surface whose art is not the owner's to reframe.
  final ArtFramingTarget? framing;

  /// The archetype's designed content, drawn over the ground (the orb shelf,
  /// the letter shelf, the platform chips). Framed cards only.
  final Widget? framedContent;

  /// The one number this card answers with, where that is not simply the first
  /// entry of [stats] — a rank answers with its tier, which is not a stat the
  /// platform publishes. Left null, the first of [stats] is the hero.
  final PersonalizationStat? hero;

  /// What the number is about, and its secondary line. Drawn over art only.
  final String? subject;
  final String? detail;

  /// Everything the card has to say in numbers. The shell decides how many of
  /// them the card's size can answer for; a card never caps its own.
  final List<PersonalizationStat> stats;

  /// A bleed card whole: its picture, and whatever it draws over it.
  ///
  /// The overlay is built inside the framing control rather than stacked on top
  /// of it. A card that answers with a number draws that number over its own
  /// picture, and anything drawn above the control both hides the mark that
  /// advertises it and takes the press that would start it — which is why
  /// framing reached only the one card that draws nothing over its art.
  Widget _bleed(BuildContext context, Widget Function(Widget picture) over) {
    final target = framing;
    final scope = ArtFramingScope.maybeOf(context);
    final url = art;
    Widget picture(ArtFraming framing) => personalizationArtOrPlaceholder(
      imageUrl: art,
      placeholder: const PersonalizationCardGround(),
      framing: framing,
    );
    if (target == null || scope == null || url == null) {
      return over(picture(target?.framing ?? ArtFraming.center));
    }
    return ArtFramingGesture(
      imageUrl: url,
      framing: target.framing,
      onChanged: (next) => scope.onChanged(target.widgetId, next),
      builder: (context, framing) => over(picture(framing)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = PersonalizationTheme.of(context);
    final format = renderedCardFormat(archetype, hasArt: art != null);
    final content = framedContent;

    return ClipRRect(
      borderRadius: BorderRadius.circular(palette.radius),
      // The only child reporting an intrinsic height, so a card's height is
      // known without loading an image; under a tight height (a stretched pair
      // slot) it takes that height instead and the fill covers it.
      child: AspectRatio(
        aspectRatio: switch (size) {
          ProfileCardSize.half => PersonalizationLayout.cardHalfAspect,
          ProfileCardSize.full when rendersPortraitFull(archetype) =>
            PersonalizationLayout.cardArtFullAspect,
          ProfileCardSize.full => PersonalizationLayout.cardFullAspect,
        },
        // The datum's type is a function of the card's real height, so the band
        // keeps its share of the card at every width instead of carrying
        // page-level sizes onto a card a fraction of that size.
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The cap lives here rather than in each card so no payload can
            // put more numbers on a card than its size answers for, however
            // many stats the platform happens to publish.
            final heroStat = hero ?? (stats.isEmpty ? null : stats.first);
            final rest = hero == null ? stats.skip(1) : stats;
            // A card designed for art that resolved none is showing a fallback:
            // its subject is a proper noun no generic label can carry, so it
            // keeps its own line. A card designed framed names its subject in
            // the hero's label and spends no line on one.
            final degraded = cardFormat(archetype) == ProfileCardFormat.bleed;
            final datum = PersonalizationDatum(
              format: format,
              cardHeight: constraints.maxHeight,
              hero: heroStat,
              subject: degraded ? subject : null,
              detail: degraded ? detail : null,
              supporting: rest
                  .take(
                    size == ProfileCardSize.full
                        ? PersonalizationLayout.supportingCapFull
                        : PersonalizationLayout.supportingCapHalf,
                  )
                  .toList(),
            );
            // A card with nothing to say draws nothing over its art. The
            // gradient exists to keep a datum legible; with no datum it is a
            // shadow across a picture for no reason.
            final datumZone = hasDatumZone(archetype);
            final hasDatum =
                datumZone &&
                (heroStat != null || (degraded && subject != null));
            return format == ProfileCardFormat.bleed
                ? _bleed(
                    context,
                    (picture) => Stack(
                      fit: StackFit.expand,
                      children: [
                        picture,
                        if (hasDatum) ...[
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
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: datum,
                          ),
                        ],
                      ],
                    ),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      const PersonalizationCardGround(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: content == null
                                ? const SizedBox.expand()
                                : Padding(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.smMd,
                                    ),
                                    child: content,
                                  ),
                          ),
                          if (datumZone) datum,
                        ],
                      ),
                    ],
                  );
          },
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
    required this.cardHeight,
    this.hero,
    this.subject,
    this.detail,
    this.supporting = const [],
  });

  final ProfileCardFormat format;

  /// The card's rendered height. Every type size here is a fraction of it, so
  /// the band holds its share of the card at any width.
  final double cardHeight;

  /// The one number the card answers with. A framed card names its subject in
  /// this entry's own label, which is why it spends no separate line on one.
  final PersonalizationStat? hero;

  /// What the number is about, where no label can name it — a character, a
  /// game title. The shell decides when a card is entitled to the line.
  final String? subject;
  final String? detail;

  /// The numbers that explain [hero], drawn beside it and smaller. A half card
  /// takes none — it carries the one datum and nothing else.
  final List<PersonalizationStat> supporting;

  @override
  Widget build(BuildContext context) {
    final palette = PersonalizationTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    // The label floor wins over the band's target share when the two disagree:
    // a band that hits its proportion with unreadable labels has traded away
    // the thing the band exists for.
    final heroSize = (PersonalizationLayout.datumHeroFactor * cardHeight).clamp(
      PersonalizationLayout.datumHeroMin,
      PersonalizationLayout.datumHeroMax,
    );
    final supportSize = (PersonalizationLayout.datumSupportFactor * cardHeight)
        .clamp(
          PersonalizationLayout.datumSupportMin,
          PersonalizationLayout.datumSupportMax,
        );
    final subjectSize = (PersonalizationLayout.datumSubjectFactor * cardHeight)
        .clamp(
          PersonalizationLayout.datumSubjectMin,
          PersonalizationLayout.datumSubjectMax,
        );
    final labelSize = (PersonalizationLayout.datumLabelFactor * cardHeight)
        .clamp(
          PersonalizationLayout.datumLabelMin,
          PersonalizationLayout.datumLabelMax,
        );
    const leading = PersonalizationLayout.datumLeading;
    final onArt = format == ProfileCardFormat.bleed;
    // Muted grey is not legible over light art even under the bottom gradient,
    // so both lines take the on-art tone there.
    final primary = onArt ? PersonalizationArtColors.onArt : palette.text;
    final secondary = onArt ? PersonalizationArtColors.onArt : palette.muted;
    final shadows = onArt ? PersonalizationArtText.shadows : null;
    final subjectText = subject;
    final detailText = detail;

    Widget entry(PersonalizationStat stat, {required bool isHero}) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stat.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium?.copyWith(
            color: primary,
            fontSize: isHero ? heroSize : supportSize,
            height: leading,
            fontWeight: AppTypography.bold,
            // Equal-advance digits, so a value that changes does not shift what
            // sits beside it. The face the app renders with today gives this
            // anyway; asking for it is what keeps the property when the face
            // changes.
            fontFeatures: const [FontFeature.tabularFigures()],
            shadows: shadows,
          ),
        ),
        Text(
          stat.label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelSmall?.copyWith(
            color: secondary,
            fontSize: labelSize,
            height: leading,
            letterSpacing: PersonalizationLayout.labelTracking,
            shadows: shadows,
          ),
        ),
      ],
    );

    final heroStat = hero;

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
              fontSize: subjectSize,
              height: leading,
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
              fontSize: labelSize,
              height: leading,
              shadows: shadows,
            ),
          ),
        if (heroStat != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              // Loose so an entry sizes to content when it fits, but stays
              // width-bounded on a narrow half card so its label ellipsizes
              // instead of forcing the Row past the card edge.
              Flexible(child: entry(heroStat, isHero: true)),
              for (final stat in supporting)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: PersonalizationLayout.datumEntryGap,
                    ),
                    child: entry(stat, isHero: false),
                  ),
                ),
            ],
          ),
      ],
    );

    const padding = EdgeInsets.symmetric(
      horizontal: PersonalizationLayout.datumHorizontalPadding,
      vertical: AppSpacing.xs,
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
