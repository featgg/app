import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../domain/game_card.dart';

/// Renders the Steam-specific `data` block: library showcase and recent games.
class SteamCardDataView extends StatelessWidget {
  const SteamCardDataView({super.key, required this.data});

  final SteamCardData data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.libraryShowcase.isNotEmpty) ...[
          Text(
            key: const Key('steamLibraryShowcaseLabel'),
            l10n.connectionsLibraryShowcase,
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: AppSpacing.xl * 3,
            child: ListView.separated(
              key: const Key('steamLibraryShowcaseList'),
              scrollDirection: Axis.horizontal,
              itemCount: data.libraryShowcase.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final entry = data.libraryShowcase[index];
                return _ShowcaseItem(entry: entry);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (data.recentGames.isNotEmpty) ...[
          Text(
            key: const Key('steamRecentGamesLabel'),
            l10n.connectionsRecentGames,
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...data.recentGames.map(
            (entry) => Padding(
              key: Key('steamRecentGame_${entry.appId}'),
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.title,
                      style: textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${entry.hours2Weeks}h',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ShowcaseItem extends StatelessWidget {
  const _ShowcaseItem({required this.entry});

  final LibraryShowcaseEntry entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const size = AppSpacing.xl * 3;

    Widget image;
    if (entry.iconImage != null) {
      image = CachedNetworkImage(
        imageUrl: entry.iconImage!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => _placeholder(colorScheme, size),
        errorWidget: (_, _, _) => _placeholder(colorScheme, size),
      );
    } else {
      image = _placeholder(colorScheme, size);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: SizedBox(width: size, height: size, child: image),
    );
  }

  Widget _placeholder(ColorScheme colorScheme, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadii.sm),
    ),
    child: Icon(
      Icons.videogame_asset_outlined,
      color: colorScheme.onSurfaceVariant,
    ),
  );
}
