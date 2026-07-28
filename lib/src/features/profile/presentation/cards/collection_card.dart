import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/core.dart';
import '../../../connections/domain/connection.dart';
import '../../../connections/domain/game_card.dart';
import '../../domain/collection_value_resolver.dart';
import '../../domain/game_collector_value_resolver.dart';
import '../../domain/profile_archetype.dart';
import '../../domain/profile_widget.dart';
import '../collection_title_labels.dart';
import '../personalization_card_shell.dart';
import '../profile_owner_cards_provider.dart';
import 'card_data.dart';
import 'card_key.dart';

/// Collection archetype: a curated multi-game shelf or the whole-library
/// "Collector" variant, branched on [ProfileWidget.kind]. Full only.
///
/// - Curated (`collection`): Steam-first (the kind carries no platform), one orb
///   per still-in-library game via the pure [resolveCollection], captioned by the
///   game title, with the game count in the datum. No game resolves → a single
///   neutral orb, no datum stats — never blank, never a fallback.
/// - Collector (`game_collector`): the bound platform's whole library as a single
///   emblem orb via the pure [resolveGameCollector], with games-owned (and hours,
///   when present) in the datum. A null resolve → the neutral emblem, no stats.
class CollectionCard extends ConsumerWidget {
  const CollectionCard({super.key, required this.widget, this.cardSource});

  final ProfileWidget widget;
  final CardSource? cardSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = PersonalizationTheme.of(context);

    if (widget.kind == ProfileWidgetKind.gameCollector) {
      final platform = widget.platform;
      final card = platform == null
          ? null
          : resolveCard(ref, cardSource, platform);
      final resolved = resolveGameCollector(card);
      return PersonalizationCardShell(
        key: personalizationCardKey(widget.id),
        archetype: ProfileArchetype.collection,
        size: ProfileCardSize.full,
        framedContent: Center(
          child: _CollectionOrb(
            orbKey: collectionOrbKey(widget.id, 0),
            palette: palette,
            imageUrl: resolved?.heroImage,
          ),
        ),
        stats: collectorStats(resolved, l10n),
      );
    }

    // Curated: a collection has no bound platform, so it resolves from Steam.
    final card = resolveCard(ref, cardSource, Platform.steam);
    final data = card?.data;
    final panels = resolveCollection(
      data is SteamCardData ? data : null,
      widget.collectionSelection,
    );
    final titleKey = widget.collectionSelection.titleKey;
    final title =
        (titleKey == null ? null : collectionTitleLabel(l10n, titleKey)) ??
        l10n.personalizationCollectionTitle;

    return PersonalizationCardShell(
      key: personalizationCardKey(widget.id),
      archetype: ProfileArchetype.collection,
      size: ProfileCardSize.full,
      // Which collection this is comes from the owner's own pick, so no written
      // label covers it and the count alone would leave two shelves on one
      // profile indistinguishable. It is the hero's label.
      hero: panels.isEmpty
          ? null
          : PersonalizationStat(
              value: formatCardValue(panels.length, l10n),
              label: title,
            ),
      framedContent: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.smMd,
          runSpacing: AppSpacing.smMd,
          children: panels.isEmpty
              ? [
                  _CollectionOrb(
                    orbKey: collectionOrbKey(widget.id, 0),
                    palette: palette,
                  ),
                ]
              : [
                  // A display cap: the shelf is a motif, and the datum below
                  // still reports every resolved game.
                  for (
                    var i = 0;
                    i < panels.length &&
                        i < PersonalizationLayout.collectionOrbCap;
                    i++
                  )
                    _CollectionOrb(
                      orbKey: collectionOrbKey(widget.id, i),
                      palette: palette,
                      caption: panels[i].title,
                      imageUrl: panels[i].heroImage,
                    ),
                ],
        ),
      ),
    );
  }
}

/// A Collection orb (mockup `.leg .orb`): a token-gradient circle with an accent
/// border and an optional 1-line caption bounded to the cell width. The gradient's
/// bottom paint is the solid mid-tone [PersonalizationPalette.artB], so
/// a theme swap re-tints it live; the art is procedural, never a bundled asset.
class _CollectionOrb extends StatelessWidget {
  const _CollectionOrb({
    required this.orbKey,
    required this.palette,
    this.caption,
    this.imageUrl,
  });

  final Key orbKey;
  final PersonalizationPalette palette;
  final String? caption;

  /// The game's cover; null → the procedural gradient orb.
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final captionText = caption;

    return SizedBox(
      width: PersonalizationLayout.collectionOrbCellWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: orbKey,
            width: PersonalizationLayout.collectionOrbSize,
            height: PersonalizationLayout.collectionOrbSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [palette.artC, palette.artA, palette.artB],
              ),
            ),
            // The accent ring stays visible over a loaded cover.
            foregroundDecoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: palette.accent,
                width: PersonalizationLayout.borderWidth,
              ),
            ),
            child: ClipOval(
              child: personalizationArtOrPlaceholder(
                imageUrl: imageUrl,
                placeholder: const SizedBox.expand(),
              ),
            ),
          ),
          if (captionText != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              captionText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: textTheme.labelSmall?.copyWith(color: palette.muted),
            ),
          ],
        ],
      ),
    );
  }
}
