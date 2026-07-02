import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../connections/domain/game_card.dart';
import '../domain/profile_widget.dart';
import '../domain/showcase_selection.dart';
import '../domain/showcase_value_resolver.dart';
import 'profile_owner_cards_provider.dart';
import 'showcase_tint_provider.dart';

/// Provisional per-size aspect ratios. The frozen display rules fix the
/// art/text *behavior* (the art never shrinks; size drives which text lines
/// show), not exact ratios — these are tunable without contract impact.
const double _smallRatio = 1 / 1;
const double _wideRatio = 2 / 1;
const double _largeRatio = 3 / 4;

/// How far the tinted label/hero blend toward [ColorScheme.onSurface]. The hero
/// blends closer to onSurface so the number stays the brightest element while
/// still reading as part of the artwork; the label keeps more of the art's hue
/// while staying legible at its smaller size.
const double _labelTintBlend = 0.30;
const double _heroTintBlend = 0.55;

/// Uppercase tag tracking (+0.5) for the label.
const double _labelTracking = 0.5;

/// Renders ONE game from a Steam `library_showcase` as a full-bleed art card:
/// the real art behind a bottom scrim, an uppercase art-tinted label, one hero
/// stat, and (at 2x2) a whisper-quiet meta line. The art is constitutive — it
/// fills its fixed-ratio box and never shrinks; the size drives which text lines
/// show (2x2 = label+hero+meta · 2x1 = label+hero inline · 1x1 = label+hero).
///
/// Resolves its card through the injected [cardSource] (like the template and
/// composed views), so the same view renders the owner's own card and a
/// visitor's public card. When the game does not resolve — card null, loading,
/// errored, or the referenced game rotated out of the current showcase — the
/// owner sees a placeholder (so the tile stays manageable) and a visitor sees
/// nothing.
class ShowcaseCardView extends ConsumerWidget {
  const ShowcaseCardView({
    super.key,
    required this.widget,
    this.cardSource,
    this.showEmptyPlaceholder = true,
  });

  final ProfileWidget widget;

  /// Where the card resolves from. Null → the owner's own card
  /// ([ownerCardProvider]); the visitor render injects a public source.
  final CardSource? cardSource;

  /// The owner sees a placeholder when the game does not resolve so the tile
  /// stays actionable; a visitor has no action, so the visitor render passes
  /// false to omit the tile entirely.
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
    // showcase never errors the tile.
    final data = cardState.hasError ? null : cardState.value?.data;
    final steam = data is SteamCardData ? data : null;
    final resolved = resolveShowcase(steam, widget.showcaseSelection);

    if (resolved == null) {
      if (!showEmptyPlaceholder) return const SizedBox.shrink();
      return _Placeholder(widgetId: widget.id);
    }

    return ClipRRect(
      key: Key('showcaseCard_${widget.id}'),
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: AspectRatio(
        aspectRatio: _ratioFor(widget.size),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Art(
              key: Key('showcaseArt_${widget.id}'),
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

/// Owner-only placeholder shown when the showcased game does not resolve, so the
/// tile stays intentional and its options menu reachable.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.widgetId});

  final String widgetId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      key: Key('showcaseEmpty_$widgetId'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      alignment: Alignment.center,
      child: Text(
        l10n.showcaseGameUnavailable,
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Full-bleed game art, or a neutral surface when the art url is null or the
/// image errors (feed image rules — never a broken-image glyph).
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

/// Identity text, arranged by size: 2x2 = label+hero+meta (column), 2x1 =
/// label+hero inline (row), 1x1 = label+hero (column). Adding/removing lines
/// never resizes the art.
class _TextBlock extends StatelessWidget {
  const _TextBlock({
    required this.widgetId,
    required this.size,
    required this.resolved,
  });

  final String widgetId;
  final ProfileWidgetSize size;
  final ResolvedShowcase resolved;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    final label = _TintedText(
      textKey: Key('showcaseLabel_$widgetId'),
      text: resolved.title.toUpperCase(),
      heroImage: resolved.heroImage,
      style: textTheme.titleMedium?.copyWith(
        fontWeight: AppTypography.semiBold,
        letterSpacing: _labelTracking,
      ),
      blend: _labelTintBlend,
      // Only the large card has room for the title to wrap; wide/small keep a
      // single ellipsized line so the hero never gets pushed out of the fade.
      maxLines: size == ProfileWidgetSize.large ? 2 : 1,
    );
    final hero = _TintedText(
      textKey: Key('showcaseHero_$widgetId'),
      text: formatShowcaseHeroValue(resolved.heroValue),
      heroImage: resolved.heroImage,
      style: textTheme.headlineMedium?.copyWith(fontWeight: AppTypography.bold),
      blend: _heroTintBlend,
    );
    // Deliberately NOT tinted — whisper-quiet secondary text.
    final meta = Text(
      _metaDescriptor(l10n, resolved.hero),
      key: Key('showcaseMeta_$widgetId'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
    );

    switch (size) {
      case ProfileWidgetSize.large:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [label, hero, meta],
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

/// Text tinted by the art's extracted swatch (single line unless the caller
/// grants more — the large card lets the game title wrap). Watches
/// [showcaseTintProvider] only when [heroImage] is non-null; while the tint
/// loads, is null, or the art is absent, it falls back to the neutral
/// [ColorScheme.onSurface] so the card renders immediately and never blocks on
/// extraction. The resolved tint is blended toward onSurface by [blend].
class _TintedText extends ConsumerWidget {
  const _TintedText({
    required this.textKey,
    required this.text,
    required this.heroImage,
    required this.style,
    required this.blend,
    this.maxLines = 1,
  });

  final Key textKey;
  final String text;
  final String? heroImage;
  final TextStyle? style;
  final double blend;
  final int maxLines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final url = heroImage;
    final tint = url == null
        ? null
        : ref.watch(showcaseTintProvider(url)).value;
    final color = tint == null
        ? onSurface
        : Color.lerp(tint, onSurface, blend)!;
    return Text(
      text,
      key: textKey,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: (style ?? const TextStyle()).copyWith(color: color),
    );
  }
}

/// Maps the hero stat to its localized descriptor. In slice 1 the meta line
/// renders the hero stat's descriptor (no second per-game datum exists yet); a
/// real second stat renders here once it arrives.
String _metaDescriptor(AppLocalizations l10n, ShowcaseHeroStat hero) =>
    switch (hero) {
      ShowcaseHeroStat.hours => l10n.connectionsStatHoursPlayed,
    };
