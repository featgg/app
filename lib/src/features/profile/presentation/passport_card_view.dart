import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../connections/domain/connection.dart';
import '../../connections/domain/game_card.dart';
import '../../connections/domain/platform_descriptor.dart';
import '../domain/passport_value_resolver.dart';
import '../domain/profile_widget.dart';
import '../domain/showcase_value_resolver.dart';
import 'profile_owner_cards_provider.dart';

/// Uppercase tag tracking (+0.5) for the label. Mirrors the sibling art cards.
const double _labelTracking = 0.5;

/// Renders the owner's linked platforms as a single typographic identity card:
/// the fixed `PASSPORT` label, the linked-platform count as the hero, and a
/// chip per linked platform carrying that platform's headline stat. It is NOT
/// an art card — no third-party logos, no brand colors — just a neutral
/// design-system surface, so a Steam-less user's mix reads the same as any
/// other.
///
/// It watches every [Platform.values] card through the injected [cardSource]
/// (owner default is [ownerCardProvider]; the visitor render injects a public
/// source), waits for all reads to settle before rendering (no hero flicker),
/// and resolves the settled cards through [resolvePassport]. A platform whose
/// read errors contributes no chip and never errors the card. When nothing
/// resolves — every read absent, or still loading — the owner sees a
/// placeholder/loader and a visitor sees nothing.
class PassportCardView extends ConsumerWidget {
  const PassportCardView({
    super.key,
    required this.widget,
    this.cardSource,
    this.showEmptyPlaceholder = true,
  });

  final ProfileWidget widget;

  /// Where each platform's card resolves from. Null → the owner's own card
  /// ([ownerCardProvider]); the visitor render injects a public source.
  final CardSource? cardSource;

  /// The owner sees a placeholder/loader when nothing resolves so the tile stays
  /// actionable; a visitor has no action, so the visitor render passes false to
  /// omit the tile entirely.
  final bool showEmptyPlaceholder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = cardSource;
    final states = <Platform, AsyncValue<GameCard?>>{
      for (final platform in Platform.values)
        platform: source == null
            ? ref.watch(ownerCardProvider(platform))
            : ref.watch(source(platform)),
    };

    // Wait-for-all: while any card is loading for the first time (no prior
    // value), show a clean loading tile (owner) / omit (visitor) — the hero
    // count settles once, never flickering 1→3→6 as reads land.
    final isFirstLoad = states.values.any((s) => s.isLoading && !s.hasValue);
    if (isFirstLoad) {
      return showEmptyPlaceholder
          ? _LoadingTile(widgetId: widget.id, size: widget.size)
          : const SizedBox.shrink();
    }

    // An errored platform resolves as absent (null) — it contributes no chip and
    // never errors the whole card.
    final cards = <Platform, GameCard?>{
      for (final entry in states.entries)
        entry.key: entry.value.hasError ? null : entry.value.value,
    };
    final resolved = resolvePassport(cards);

    if (resolved == null) {
      if (!showEmptyPlaceholder) return const SizedBox.shrink();
      return _Placeholder(widgetId: widget.id);
    }

    return _Passport(
      key: Key('passportCard_${widget.id}'),
      widgetId: widget.id,
      size: widget.size,
      resolved: resolved,
    );
  }
}

/// How many platform chips the card draws at each size; entries beyond the cap
/// collapse into a `+N` pill. Tunable design values. Public so tests key off it
/// rather than a literal.
int passportChipCap(ProfileWidgetSize size) => switch (size) {
  ProfileWidgetSize.small => 3,
  ProfileWidgetSize.wide => 4,
  ProfileWidgetSize.large => 6,
};

/// The resolved passport: the `PASSPORT` label, the linked-platform hero count,
/// the `worlds` meta line, and a chip cluster (capped, with a `+N` pill for the
/// overflow). Content-height on a neutral surface — no art, so it never claims a
/// fixed aspect ratio.
class _Passport extends StatelessWidget {
  const _Passport({
    super.key,
    required this.widgetId,
    required this.size,
    required this.resolved,
  });

  final String widgetId;
  final ProfileWidgetSize size;
  final ResolvedPassport resolved;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final cap = passportChipCap(size);
    final shown = resolved.entries.length < cap ? resolved.entries.length : cap;
    final overflow = resolved.entries.length - shown;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: ColoredBox(
        color: colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.passportLabel.toUpperCase(),
                key: Key('passportLabel_$widgetId'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: AppTypography.semiBold,
                  letterSpacing: _labelTracking,
                ),
              ),
              Text(
                formatShowcaseHeroValue(resolved.linkedCount),
                key: Key('passportHero_$widgetId'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.headlineMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: AppTypography.bold,
                ),
              ),
              Text(
                l10n.passportWorlds(resolved.linkedCount),
                key: Key('passportWorlds_$widgetId'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.smMd),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (var i = 0; i < shown; i++)
                    _Chip(
                      widgetId: widgetId,
                      entry: resolved.entries[i],
                      size: size,
                    ),
                  if (overflow > 0)
                    _MorePill(widgetId: widgetId, overflow: overflow),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One platform's chip. Density follows the card size: name-only (small), name
/// + compact value (wide), name + stat label + value (large). An identity-only
/// entry (no headline number) shows the platform name alone at every size.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.widgetId,
    required this.entry,
    required this.size,
  });

  final String widgetId;
  final PassportEntry entry;
  final ProfileWidgetSize size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Brand-correct platform name (a proper noun, intentionally not localized) —
    // text only, never a logo or brand color.
    final name =
        platformDescriptors[entry.platform]?.displayName ?? entry.platform.name;
    final value = _formatValue(entry);
    final labelKey = entry.statLabelKey;
    final statLabel = labelKey == null ? null : _statLabel(l10n, labelKey);

    final Widget content;
    switch (size) {
      case ProfileWidgetSize.small:
        content = Text(
          name,
          style: textTheme.labelMedium?.copyWith(
            color: colorScheme.onSecondaryContainer,
            fontWeight: AppTypography.medium,
          ),
        );
      case ProfileWidgetSize.wide:
        content = Text(
          value == null ? name : '$name  $value',
          style: textTheme.labelMedium?.copyWith(
            color: colorScheme.onSecondaryContainer,
            fontWeight: AppTypography.medium,
          ),
        );
      case ProfileWidgetSize.large:
        content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontWeight: AppTypography.semiBold,
              ),
            ),
            if (value != null)
              Text(
                statLabel == null ? value : '$statLabel  $value',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
          ],
        );
    }

    return Container(
      key: Key('passportChip_${widgetId}_${entry.platform.name}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smMd,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: content,
    );
  }
}

/// The `+N` overflow pill shown when there are more linked platforms than the
/// size's chip cap; the hero count stays the true linked-platform total.
class _MorePill extends StatelessWidget {
  const _MorePill({required this.widgetId, required this.overflow});

  final String widgetId;
  final int overflow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      key: Key('passportMore_$widgetId'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smMd,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        l10n.passportMore(overflow),
        style: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: AppTypography.medium,
        ),
      ),
    );
  }
}

/// The owner loading tile's footprint at each size. Mirrors the resolved card's
/// per-size growth (taller as the chip cap grows) so the neutral loader reserves
/// roughly the card's height and the tile does not resize when the count
/// settles. Reads named metrics rather than a raw dimension.
double _loadingHeightFor(ProfileWidgetSize size) => switch (size) {
  ProfileWidgetSize.small => AppPassportMetrics.loadingHeightSmall,
  ProfileWidgetSize.wide => AppPassportMetrics.loadingHeightWide,
  ProfileWidgetSize.large => AppPassportMetrics.loadingHeightLarge,
};

/// Owner-only loading tile shown while any card is fetching for the first time:
/// a clean neutral surface at the size's footprint, never the empty motif, so a
/// still-loading passport never reads as absent. No animation (no shimmer
/// dependency).
class _LoadingTile extends StatelessWidget {
  const _LoadingTile({required this.widgetId, required this.size});

  final String widgetId;
  final ProfileWidgetSize size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      key: Key('passportLoading_$widgetId'),
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: ColoredBox(
        color: colorScheme.surfaceContainerHighest,
        child: SizedBox(
          height: _loadingHeightFor(size),
          width: double.infinity,
        ),
      ),
    );
  }
}

/// Owner-only motif shown when no platform resolves, so the tile stays
/// intentional and its options menu reachable: a neutral surface with a glyph
/// and the localized unavailable line.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.widgetId});

  final String widgetId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ClipRRect(
      key: Key('passportEmpty_$widgetId'),
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: ColoredBox(
        color: colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.public_outlined,
                key: Key('passportEmptyMotif_$widgetId'),
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.passportUnavailable,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Formats a chip's headline value with its stable unit suffix, or null for an
/// identity-only entry. `%` for a percent unit, ` LP` for an lp unit (the
/// `formatLolRank` precedent); every other unit renders the bare number — the
/// chip's stat label already names it.
String? _formatValue(PassportEntry entry) {
  final value = entry.value;
  if (value == null) return null;
  final base = formatShowcaseHeroValue(value);
  return switch (entry.unit) {
    'percent' => '$base%',
    'lp' => '$base LP',
    _ => base,
  };
}

/// Maps a headline stat's `connectionsStat*` key to its localized label. The
/// single place these stable keys resolve to copy, keeping strings out of the
/// resolver and its tests.
String? _statLabel(AppLocalizations l10n, String key) => switch (key) {
  'connectionsStatRating' => l10n.connectionsStatRating,
  'connectionsStatGamesOwned' => l10n.connectionsStatGamesOwned,
  'connectionsStatHoursPlayed' => l10n.connectionsStatHoursPlayed,
  'connectionsStatNetworkLevel' => l10n.connectionsStatNetworkLevel,
  'connectionsStatTotalAchievementPoints' =>
    l10n.connectionsStatTotalAchievementPoints,
  'connectionsStatRetroRank' => l10n.connectionsStatRetroRank,
  'connectionsStatItemLevel' => l10n.connectionsStatItemLevel,
  'connectionsStatRankLp' => l10n.connectionsStatRankLp,
  'connectionsStatWinrate' => l10n.connectionsStatWinrate,
  'connectionsStatWvwRank' => l10n.connectionsStatWvwRank,
  'connectionsStatFractalLevel' => l10n.connectionsStatFractalLevel,
  'connectionsStatVeterancyYears' => l10n.connectionsStatVeterancyYears,
  _ => null,
};
