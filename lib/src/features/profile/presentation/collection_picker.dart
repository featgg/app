import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../connections/domain/game_card.dart';
import '../domain/collection_selection.dart';
import '../domain/collection_title_catalog.dart';
import 'collection_title_labels.dart';
import 'profile_widgets_controller.dart';

/// Collection text sits on the dark art scrim in BOTH themes, so its neutral
/// color must always be light — dark theme's `onSurface` already is, light theme
/// needs the inverse role. Mirrors the showcase picker/card.
Color _onArtColor(ColorScheme scheme) => scheme.brightness == Brightness.dark
    ? scheme.onSurface
    : scheme.onInverseSurface;

/// The Collection mode of the add-card sheet: a catalog title chooser plus a
/// multi-select grid of the owner's Steam library games, confirmed into one
/// collection card. Catalog-only — no free-text title field. Enforces the 3–5
/// selection bounds and a required title on the confirm button; a collection may
/// reuse any game, so there is no "already added" exclusion.
class CollectionPickerBody extends ConsumerStatefulWidget {
  const CollectionPickerBody({
    super.key,
    required this.games,
    required this.nextPosition,
  });

  /// The owner's Steam library-showcase games, offered as multi-select tiles.
  final List<LibraryShowcaseEntry> games;

  /// The position a confirmed collection is inserted at (max+1).
  final int nextPosition;

  @override
  ConsumerState<CollectionPickerBody> createState() =>
      _CollectionPickerBodyState();
}

class _CollectionPickerBodyState extends ConsumerState<CollectionPickerBody> {
  /// Ordered selected app ids; add order is the stored render order.
  final List<String> _selected = [];
  String? _titleKey;

  bool get _canAdd =>
      _selected.length >= kCollectionMinGames &&
      _selected.length <= kCollectionMaxGames &&
      _titleKey != null;

  void _toggle(String appId) {
    setState(() {
      if (_selected.contains(appId)) {
        _selected.remove(appId);
      } else if (_selected.length < kCollectionMaxGames) {
        // A tap on an unselected tile while already at the cap is ignored.
        _selected.add(appId);
      }
    });
  }

  void _confirm() {
    ref
        .read(profileWidgetsControllerProvider.notifier)
        .addCollection(
          selection: CollectionSelection(
            gameRefs: List.of(_selected),
            titleKey: _titleKey,
          ),
          position: widget.nextPosition,
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    // While a save is in flight, disable the confirm and the toggles so a second
    // write cannot be issued before the read provider refreshes. Mirrors the
    // composed/slot sheets' in-flight gating.
    final saving = ref.watch(profileWidgetsControllerProvider).isLoading;
    final games = widget.games;

    if (games.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.collectionPickerTitle,
            key: const Key('collectionPickerTitle'),
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.showcasePickerEmpty,
            key: const Key('showcasePickerEmpty'),
            style: textTheme.bodyMedium,
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.collectionPickerTitle,
          key: const Key('collectionPickerTitle'),
          style: textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(l10n.collectionPickerHint, style: textTheme.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.collectionPickerChooseTitle, style: textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            for (final key in collectionTitleCatalog)
              ChoiceChip(
                key: Key('collectionTitleChip_$key'),
                label: Text(collectionTitleLabel(l10n, key) ?? key),
                selected: _titleKey == key,
                onSelected: saving
                    ? null
                    : (isSelected) =>
                          setState(() => _titleKey = isSelected ? key : null),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // The grid and the confirm button scroll with the shared sheet surface,
        // not a nested scroll view, so neither is stranded on a phone.
        LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = (constraints.maxWidth - AppSpacing.sm) / 2;
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final game in games)
                  SizedBox(
                    width: tileWidth,
                    child: _CollectionGameTile(
                      entry: game,
                      selected: _selected.contains(game.appId.toString()),
                      onTap: saving
                          ? null
                          : () => _toggle(game.appId.toString()),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          key: const Key('collectionPickerAddButton'),
          onPressed: (_canAdd && !saving) ? _confirm : null,
          child: Text(l10n.collectionPickerAdd),
        ),
      ],
    );
  }
}

/// One library game as a square art tile with a check overlay when selected.
/// Tapping toggles membership; a null/erroring art url degrades to a neutral
/// surface (never a broken-image glyph).
class _CollectionGameTile extends StatelessWidget {
  const _CollectionGameTile({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final LibraryShowcaseEntry entry;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final surface = colorScheme.surfaceContainerHighest;
    final url = entry.heroImage;

    return GestureDetector(
      key: Key('collectionPickerTile_${entry.appId}'),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url == null)
                ColoredBox(color: surface)
              else
                CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => ColoredBox(color: surface),
                  errorWidget: (_, _, _) => ColoredBox(color: surface),
                ),
              const _TileScrim(),
              Positioned(
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                bottom: AppSpacing.sm,
                child: Text(
                  entry.title.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    color: _onArtColor(colorScheme),
                    fontWeight: AppTypography.semiBold,
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: Icon(
                    Icons.check_circle,
                    key: Key('collectionTileCheck_${entry.appId}'),
                    color: colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom-anchored scrim over the art for title legibility. Mirrors the showcase
/// picker's tile scrim.
class _TileScrim extends StatelessWidget {
  const _TileScrim();

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
