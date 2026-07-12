import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../connections/domain/game_card.dart';
import '../domain/game_collector_value_resolver.dart';
import '../domain/profile_widget.dart';
import '../domain/showcase_value_resolver.dart';
import 'profile_owner_cards_provider.dart';

/// Per-size aspect ratios, shared with the showcase/collection cards so the
/// collector sits in the same visual family and the grid's size→shape mapping is
/// unchanged.
const double _smallRatio = 1 / 1;
const double _wideRatio = 2 / 1;
const double _largeRatio = 3 / 4;

/// Uppercase tag tracking (+0.5) for the label. Mirrors the showcase card.
const double _labelTracking = 0.5;

/// Collector text sits on the dark art scrim in BOTH themes, so its neutral
/// color must always be light — dark theme's `onSurface` already is, light theme
/// needs the inverse role. Mirrors the showcase/collection card views. The cover
/// is a single game, but the collector card renders untinted (the collection
/// precedent), so the label uses this neutral color.
Color _onArtColor(ColorScheme scheme) => scheme.brightness == Brightness.dark
    ? scheme.onSurface
    : scheme.onInverseSurface;

Color _onArtSecondaryColor(ColorScheme scheme) =>
    scheme.brightness == Brightness.dark
    ? scheme.onSurfaceVariant
    : scheme.onInverseSurface.withValues(alpha: 0.8);

/// Renders a platform's whole library as a frozen-grammar art card: the fixed
/// `GAME COLLECTOR` label, the games-owned count as the hero, the total library
/// hours as a whisper-quiet meta line (2x2 only), over the top game's cover. The
/// art is constitutive — it fills its fixed-ratio box and never shrinks; the
/// size drives which text lines show (2x2 = label+hero+meta · 2x1 = label+hero
/// inline · 1x1 = label+hero).
///
/// Resolves its card from [widget.platform] (Steam by binding) through the
/// injected [cardSource] (like the showcase view), so the same view renders the
/// owner's own card and a visitor's public card. When nothing resolves — card
/// null, loading, errored, or the card publishes no `games_owned` — the owner
/// sees a placeholder (so the tile stays manageable) and a visitor sees nothing.
class GameCollectorCardView extends ConsumerWidget {
  const GameCollectorCardView({
    super.key,
    required this.widget,
    this.cardSource,
    this.showEmptyPlaceholder = true,
  });

  final ProfileWidget widget;

  /// Where the card resolves from. Null → the owner's own card
  /// ([ownerCardProvider]); the visitor render injects a public source.
  final CardSource? cardSource;

  /// The owner sees a placeholder when nothing resolves so the tile stays
  /// actionable; a visitor has no action, so the visitor render passes false to
  /// omit the tile entirely.
  final bool showEmptyPlaceholder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = widget.platform;
    final source = cardSource;
    final cardState = platform == null
        ? const AsyncData<GameCard?>(null)
        : (source == null
              ? ref.watch(ownerCardProvider(platform))
              : ref.watch(source(platform)));

    // AsyncLoading with nothing resolved yet is distinct from resolved-absent:
    // during first load show a clean loading tile (owner) / omit (visitor), never
    // the empty state — so the already-present watch can swap in the card the
    // instant it resolves, with no leave/re-enter.
    final isFirstLoad = cardState.isLoading && !cardState.hasValue;

    // An errored card resolves as unresolved (mirrors the other card views): the
    // collector never errors the tile. The whole card is needed — the figures
    // live in the envelope `stats`, not just the platform data block.
    final card = cardState.hasError ? null : cardState.value;
    final resolved = resolveGameCollector(card);

    // A card with no value OR a zero count reads as empty — a bare "0" over a
    // blank surface is the state the motif replaces.
    if (resolved == null || resolved.gamesOwned == 0) {
      if (isFirstLoad) {
        return showEmptyPlaceholder
            ? _LoadingTile(widgetId: widget.id, size: widget.size)
            : const SizedBox.shrink();
      }
      if (!showEmptyPlaceholder) return const SizedBox.shrink();
      return _Placeholder(widgetId: widget.id, size: widget.size);
    }

    return ClipRRect(
      key: Key('gameCollectorCard_${widget.id}'),
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: AspectRatio(
        aspectRatio: _ratioFor(widget.size),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Art(
              key: Key('gameCollectorArt_${widget.id}'),
              heroImage: resolved.heroImage,
            ),
            const _Fade(),
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: _TextBlock(
                widgetId: widget.id,
                size: widget.size,
                resolved: resolved,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double _ratioFor(ProfileWidgetSize size) => switch (size) {
  ProfileWidgetSize.small => _smallRatio,
  ProfileWidgetSize.wide => _wideRatio,
  ProfileWidgetSize.large => _largeRatio,
};

/// Owner-only loading tile shown while the card is fetching for the first time
/// (no prior value): a clean neutral surface at the card footprint, never the
/// empty motif, so a still-loading card never reads as absent. No animation (no
/// shimmer dependency); mirrors the neutral card skeleton.
class _LoadingTile extends StatelessWidget {
  const _LoadingTile({required this.widgetId, required this.size});

  final String widgetId;
  final ProfileWidgetSize size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      key: Key('gameCollectorLoading_$widgetId'),
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: AspectRatio(
        aspectRatio: _ratioFor(size),
        child: ColoredBox(color: colorScheme.surfaceContainerHighest),
      ),
    );
  }
}

/// Owner-only motif shown when nothing resolves or the count reads as empty, so
/// the tile stays intentional and its options menu reachable: a collection glyph
/// at the card footprint with the localized line beneath. Mirrors the showcase
/// motif.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.widgetId, required this.size});

  final String widgetId;
  final ProfileWidgetSize size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ClipRRect(
      key: Key('gameCollectorEmpty_$widgetId'),
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: AspectRatio(
        aspectRatio: _ratioFor(size),
        child: ColoredBox(
          color: colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.videogame_asset_outlined,
                  key: Key('gameCollectorEmptyMotif_$widgetId'),
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.gameCollectorUnavailable,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-bleed cover art, or a neutral surface when the art url is null or the
/// image errors (feed image rules — never a broken-image glyph). Mirrors the
/// showcase card's art tile.
class _Art extends StatelessWidget {
  const _Art({super.key, required this.heroImage});

  final String? heroImage;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;
    final url = heroImage;
    if (url == null) return ColoredBox(color: surface);
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => ColoredBox(color: surface),
      errorWidget: (_, _, _) => ColoredBox(color: surface),
    );
  }
}

/// Bottom-anchored scrim (`rgba(0,0,0,.55)` → `0`) over the art for legibility.
/// Mirrors the showcase card's fade.
class _Fade extends StatelessWidget {
  const _Fade();

  @override
  Widget build(BuildContext context) {
    final scrim = Theme.of(context).colorScheme.scrim;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [scrim.withValues(alpha: 0.55), scrim.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

/// Bottom-left identity text, arranged by size: 2x2 = label + hero + meta
/// (column), 2x1 = label + hero inline (row), 1x1 = label + hero (column). The
/// meta line (total hours) shows only at large size and only when the card
/// carries the hours stat. Adding/removing lines never resizes the art. The
/// hero is a bare count — the fixed `GAME COLLECTOR` label already names it.
class _TextBlock extends StatelessWidget {
  const _TextBlock({
    required this.widgetId,
    required this.size,
    required this.resolved,
  });

  final String widgetId;
  final ProfileWidgetSize size;
  final ResolvedGameCollector resolved;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    final label = Text(
      l10n.gameCollectorLabel.toUpperCase(),
      key: Key('gameCollectorLabel_$widgetId'),
      maxLines: size == ProfileWidgetSize.large ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: textTheme.titleMedium?.copyWith(
        color: _onArtColor(colorScheme),
        fontWeight: AppTypography.semiBold,
        letterSpacing: _labelTracking,
      ),
    );
    final hero = Text(
      formatShowcaseHeroValue(resolved.gamesOwned),
      key: Key('gameCollectorHero_$widgetId'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textTheme.headlineMedium?.copyWith(
        color: _onArtColor(colorScheme),
        fontWeight: AppTypography.bold,
      ),
    );
    final hours = resolved.hoursPlayed;
    final meta = hours == null
        ? null
        : Text(
            l10n.showcaseHeroHoursCompact(formatShowcaseHeroValue(hours)),
            key: Key('gameCollectorMeta_$widgetId'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: _onArtSecondaryColor(colorScheme),
            ),
          );

    switch (size) {
      case ProfileWidgetSize.large:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [label, hero, ?meta],
        );
      case ProfileWidgetSize.wide:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: label),
            const SizedBox(width: AppSpacing.sm),
            hero,
          ],
        );
      case ProfileWidgetSize.small:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [label, hero],
        );
    }
  }
}
