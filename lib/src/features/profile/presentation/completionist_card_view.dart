import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../connections/domain/game_card.dart';
import '../domain/completionist_value_resolver.dart';
import '../domain/profile_widget.dart';
import '../domain/showcase_value_resolver.dart';
import 'profile_owner_cards_provider.dart';

/// Per-size aspect ratios, shared with the showcase/collection/collector cards
/// so the completionist sits in the same visual family and the grid's size→shape
/// mapping is unchanged.
const double _smallRatio = 1 / 1;
const double _wideRatio = 2 / 1;
const double _largeRatio = 3 / 4;

/// Uppercase tag tracking (+0.5) for the label. Mirrors the showcase card.
const double _labelTracking = 0.5;

/// Completionist text sits on the dark art scrim in BOTH themes, so its neutral
/// color must always be light — dark theme's `onSurface` already is, light theme
/// needs the inverse role. Mirrors the collector/showcase card views. The cover
/// is a single game, but the card renders untinted (the collector precedent), so
/// the label uses this neutral color.
Color _onArtColor(ColorScheme scheme) => scheme.brightness == Brightness.dark
    ? scheme.onSurface
    : scheme.onInverseSurface;

Color _onArtSecondaryColor(ColorScheme scheme) =>
    scheme.brightness == Brightness.dark
    ? scheme.onSurfaceVariant
    : scheme.onInverseSurface.withValues(alpha: 0.8);

/// Renders a platform's whole-library perfect-games count as a frozen-grammar art
/// card: the fixed `COMPLETIONIST` label, the perfect-games count as the hero,
/// the games-owned count as a whisper-quiet `of {owned}` meta line (2x2 only),
/// over the top game's cover. The art is constitutive — it fills its fixed-ratio
/// box and never shrinks; the size drives which text lines show (2x2 =
/// label+hero+meta · 2x1 = label+hero inline · 1x1 = label+hero).
///
/// Resolves its card from [widget.platform] (Steam by binding) through the
/// injected [cardSource] (like the collector view), so the same view renders the
/// owner's own card and a visitor's public card. When nothing resolves — card
/// null, loading, errored, or the card publishes no `games_perfect` — the owner
/// sees a placeholder (so the tile stays manageable) and a visitor sees nothing.
class CompletionistCardView extends ConsumerWidget {
  const CompletionistCardView({
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

    // An errored card resolves as unresolved (mirrors the other card views): the
    // completionist never errors the tile. The whole card is needed — the figures
    // live in the envelope `stats`, not just the platform data block.
    final card = cardState.hasError ? null : cardState.value;
    final resolved = resolveCompletionist(card);

    if (resolved == null) {
      if (!showEmptyPlaceholder) return const SizedBox.shrink();
      return _Placeholder(widgetId: widget.id);
    }

    return ClipRRect(
      key: Key('completionistCard_${widget.id}'),
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: AspectRatio(
        aspectRatio: _ratioFor(widget.size),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Art(
              key: Key('completionistArt_${widget.id}'),
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

/// Owner-only placeholder shown when nothing resolves, so the tile stays
/// intentional and its options menu reachable. Mirrors the collector placeholder.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.widgetId});

  final String widgetId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      key: Key('completionistEmpty_$widgetId'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      alignment: Alignment.center,
      child: Text(
        l10n.completionistUnavailable,
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Full-bleed cover art, or a neutral surface when the art url is null or the
/// image errors (feed image rules — never a broken-image glyph). Mirrors the
/// collector card's art tile.
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
/// Mirrors the collector card's fade.
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
/// meta line (`of {owned}` — the completion denominator) shows only at large size
/// and only when the card carries the owned-games stat. Adding/removing lines
/// never resizes the art. The hero is a bare count — the fixed `COMPLETIONIST`
/// label already names it.
class _TextBlock extends StatelessWidget {
  const _TextBlock({
    required this.widgetId,
    required this.size,
    required this.resolved,
  });

  final String widgetId;
  final ProfileWidgetSize size;
  final ResolvedCompletionist resolved;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    final label = Text(
      l10n.completionistLabel.toUpperCase(),
      key: Key('completionistLabel_$widgetId'),
      maxLines: size == ProfileWidgetSize.large ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: textTheme.titleMedium?.copyWith(
        color: _onArtColor(colorScheme),
        fontWeight: AppTypography.semiBold,
        letterSpacing: _labelTracking,
      ),
    );
    final hero = Text(
      formatShowcaseHeroValue(resolved.gamesPerfect),
      key: Key('completionistHero_$widgetId'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textTheme.headlineMedium?.copyWith(
        color: _onArtColor(colorScheme),
        fontWeight: AppTypography.bold,
      ),
    );
    final owned = resolved.gamesOwned;
    final meta = owned == null
        ? null
        : Text(
            l10n.completionistMetaOfOwned(formatShowcaseHeroValue(owned)),
            key: Key('completionistMeta_$widgetId'),
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
