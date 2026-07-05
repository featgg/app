import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../connections/domain/connection.dart';
import '../../connections/domain/game_card.dart';
import '../domain/collection_value_resolver.dart';
import '../domain/profile_widget.dart';
import 'collection_title_labels.dart';
import 'profile_owner_cards_provider.dart';

/// Per-size aspect ratios, shared with the showcase card so the collection sits
/// in the same visual family and the grid's size→shape mapping is unchanged.
const double _smallRatio = 1 / 1;
const double _wideRatio = 2 / 1;
const double _largeRatio = 3 / 4;

/// How far each divider slants across the card height: the top and bottom of a
/// divider sit `h * _slantFactor` apart horizontally, so the cut reads as a
/// clean angle without eating panel width.
const double _slantFactor = 0.18;

/// Uppercase tag tracking (+0.5) for the label. Mirrors the showcase card.
const double _labelTracking = 0.5;

/// Collection text sits on the dark art scrim in BOTH themes, so its neutral
/// color must always be light — dark theme's `onSurface` already is, light theme
/// needs the inverse role. Mirrors the showcase card view. Multi-panel art has
/// no single swatch, so the label uses this neutral color (no per-panel tint).
Color _onArtColor(ColorScheme scheme) => scheme.brightness == Brightness.dark
    ? scheme.onSurface
    : scheme.onInverseSurface;

Color _onArtSecondaryColor(ColorScheme scheme) =>
    scheme.brightness == Brightness.dark
    ? scheme.onSurfaceVariant
    : scheme.onInverseSurface.withValues(alpha: 0.8);

/// Renders a multi-game "panorama" of 3–5 angled art panels sharing one bottom
/// fade, on the same on-art color / typography grammar as the showcase card.
/// The panels are complementary [ClipPath] bands split by shared diagonal
/// boundaries (seam-free by construction); a cut painter strokes the dividers so
/// the "clean cuts" read crisply.
///
/// A collection has a null platform, so it always resolves from the Steam card
/// (owner's own via [ownerCardProvider], or the injected public [cardSource]),
/// Steam-first like the showcase. When nothing resolves — card null, loading,
/// errored, or every referenced game rotated out — the owner sees a placeholder
/// (so the tile stays manageable) and a visitor sees nothing.
class CollectionCardView extends ConsumerWidget {
  const CollectionCardView({
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
    final source = cardSource;
    final cardState = source == null
        ? ref.watch(ownerCardProvider(Platform.steam))
        : ref.watch(source(Platform.steam));

    // An errored card resolves as unresolved (mirrors the other card views).
    final data = cardState.hasError ? null : cardState.value?.data;
    final steam = data is SteamCardData ? data : null;
    final panels = resolveCollection(steam, widget.collectionSelection);

    if (panels.isEmpty) {
      if (!showEmptyPlaceholder) return const SizedBox.shrink();
      return _Placeholder(widgetId: widget.id);
    }

    final titleKey = widget.collectionSelection.titleKey;
    final label = titleKey == null
        ? null
        : collectionTitleLabel(AppLocalizations.of(context), titleKey);

    return ClipRRect(
      key: Key('collectionCard_${widget.id}'),
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: AspectRatio(
        aspectRatio: _ratioFor(widget.size),
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < panels.length; i++)
              Positioned.fill(
                key: Key('collectionPanel_${widget.id}_$i'),
                child: ClipPath(
                  clipper: _PanelClipper(index: i, count: panels.length),
                  child: _Art(
                    key: Key('collectionArt_${widget.id}_$i'),
                    heroImage: panels[i].heroImage,
                  ),
                ),
              ),
            if (panels.length > 1)
              Positioned.fill(
                child: CustomPaint(
                  key: Key('collectionCuts_${widget.id}'),
                  painter: _CutsPainter(
                    count: panels.length,
                    color: Theme.of(context).colorScheme.surface,
                  ),
                ),
              ),
            const _Fade(),
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: _TextBlock(
                widgetId: widget.id,
                size: widget.size,
                label: label,
                count: panels.length,
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

/// Clips panel [index] of [count] to its slanted band. Adjacent panels are cut
/// from the SAME dividing line, so the bands tile with no gap and no overlap;
/// the outer left/right edges stay vertical (straight card edges).
class _PanelClipper extends CustomClipper<Path> {
  const _PanelClipper({required this.index, required this.count});

  final int index;
  final int count;

  /// The x of divider [k] (0..count) at the given [height]/[width]. Interior
  /// dividers slant by `height * _slantFactor` (top shifted right, bottom left);
  /// the outer edges (k == 0, k == count) are pinned vertical.
  double _dividerX(int k, double width, double height, {required bool atTop}) {
    if (k == 0) return 0;
    if (k == count) return width;
    final band = width / count;
    final slant = height * _slantFactor;
    return k * band + (atTop ? slant / 2 : -slant / 2);
  }

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(_dividerX(index, w, h, atTop: true), 0)
      ..lineTo(_dividerX(index + 1, w, h, atTop: true), 0)
      ..lineTo(_dividerX(index + 1, w, h, atTop: false), h)
      ..lineTo(_dividerX(index, w, h, atTop: false), h)
      ..close();
  }

  @override
  bool shouldReclip(_PanelClipper oldClipper) =>
      oldClipper.index != index || oldClipper.count != count;
}

/// Strokes the `count - 1` diagonal dividers between panels so the clean cuts
/// read as crisp separations. Drawn above the panels, below the fade.
class _CutsPainter extends CustomPainter {
  const _CutsPainter({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final band = size.width / count;
    final slant = size.height * _slantFactor;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (var k = 1; k < count; k++) {
      canvas.drawLine(
        Offset(k * band + slant / 2, 0),
        Offset(k * band - slant / 2, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CutsPainter oldDelegate) =>
      oldDelegate.count != count || oldDelegate.color != color;
}

/// Owner-only placeholder shown when no game resolves, so the tile stays
/// intentional and its options menu reachable. Mirrors the showcase placeholder.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.widgetId});

  final String widgetId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      key: Key('collectionEmpty_$widgetId'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      alignment: Alignment.center,
      child: Text(
        l10n.collectionUnavailable,
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Full-bleed game art over the whole panel box (the clip reveals only the
/// panel's band), or a neutral surface when the art url is null or the image
/// errors (feed image rules — never a broken-image glyph). Mirrors the showcase
/// card's art tile.
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

/// Bottom-anchored scrim (`rgba(0,0,0,.55)` → `0`) over the whole panorama for
/// legibility. Identical to the showcase card's fade.
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

/// Bottom-left identity text: the catalog title label (uppercased) and a game
/// count, gated by size — large = label(≤2 lines) + meta · wide = label(1) +
/// meta · small = label(1) only. The label is omitted entirely when the title
/// key does not resolve.
class _TextBlock extends StatelessWidget {
  const _TextBlock({
    required this.widgetId,
    required this.size,
    required this.label,
    required this.count,
  });

  final String widgetId;
  final ProfileWidgetSize size;
  final String? label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    final showMeta = size != ProfileWidgetSize.small;
    final labelText = label;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText != null)
          Text(
            labelText.toUpperCase(),
            key: Key('collectionLabel_$widgetId'),
            maxLines: size == ProfileWidgetSize.large ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleMedium?.copyWith(
              color: _onArtColor(colorScheme),
              fontWeight: AppTypography.semiBold,
              letterSpacing: _labelTracking,
            ),
          ),
        if (showMeta)
          Text(
            l10n.collectionMetaGames(count),
            key: Key('collectionMeta_$widgetId'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: _onArtSecondaryColor(colorScheme),
            ),
          ),
      ],
    );
  }
}
