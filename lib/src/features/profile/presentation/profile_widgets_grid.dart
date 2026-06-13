import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../core/core.dart';
import '../../connections/domain/game_card.dart';
import '../domain/profile_widget.dart';
import 'profile_owner_cards_provider.dart';
import 'profile_screen.dart';
import 'profile_widgets_controller.dart';

/// Maps a [ProfileWidgetSize] to its staggered-grid cross-axis span on the
/// fixed 2-column base grid.
int crossAxisCellsFor(ProfileWidgetSize size) => switch (size) {
  ProfileWidgetSize.small => 1,
  ProfileWidgetSize.wide => 2,
  ProfileWidgetSize.large => 2,
};

/// Maps a [ProfileWidgetSize] to its staggered-grid main-axis span.
int mainAxisCellsFor(ProfileWidgetSize size) => switch (size) {
  ProfileWidgetSize.small => 1,
  ProfileWidgetSize.wide => 1,
  ProfileWidgetSize.large => 2,
};

/// Renders the owner's profile widgets in an auto-packing staggered grid. Each
/// [ProfileWidgetKind.platform] widget renders its card via the
/// composition-root-injected [cardBuilder]; a widget whose card is not
/// available renders a placeholder that keeps its options menu reachable, so
/// the widget stays manageable (it is never shown as an error tile).
///
/// Hidden (disabled) widgets stay in the grid rendered in a dimmed state with a
/// "Show" action so hiding is reversible; enabled widgets expose "Hide".
///
/// The grid is non-scrolling and is composed inside the profile screen's own
/// scroll view. The per-tile options menu drives the
/// [ProfileWidgetsController] (resize / hide / show / remove / reorder).
class ProfileWidgetsGrid extends ConsumerWidget {
  const ProfileWidgetsGrid({
    super.key,
    required this.widgets,
    required this.cardBuilder,
  });

  final List<ProfileWidget> widgets;
  final OwnerCardBuilder cardBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordered = [...widgets]
      ..sort((a, b) => a.position.compareTo(b.position));
    final orderedIds = [for (final w in ordered) w.id];

    void reorderMoving(String id, int delta) {
      final from = orderedIds.indexOf(id);
      final to = from + delta;
      if (from < 0 || to < 0 || to >= orderedIds.length) return;
      final next = [...orderedIds];
      next
        ..removeAt(from)
        ..insert(to, id);
      ref.read(profileWidgetsControllerProvider.notifier).reorder(next);
    }

    return StaggeredGrid.count(
      crossAxisCount: 2,
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      children: [
        for (var i = 0; i < ordered.length; i++)
          StaggeredGridTile.count(
            key: Key('profileWidgetTile_${ordered[i].id}'),
            crossAxisCellCount: crossAxisCellsFor(ordered[i].size),
            mainAxisCellCount: mainAxisCellsFor(ordered[i].size),
            child: _WidgetTile(
              widget: ordered[i],
              cardBuilder: cardBuilder,
              canMoveUp: i > 0,
              canMoveDown: i < ordered.length - 1,
              onMoveUp: () => reorderMoving(ordered[i].id, -1),
              onMoveDown: () => reorderMoving(ordered[i].id, 1),
            ),
          ),
      ],
    );
  }
}

/// Resolves and renders a single widget's card content, with an options menu
/// overlay. A widget whose card is not available renders a placeholder that
/// keeps the options menu reachable, so the widget stays manageable.
class _WidgetTile extends ConsumerWidget {
  const _WidgetTile({
    required this.widget,
    required this.cardBuilder,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final ProfileWidget widget;
  final OwnerCardBuilder cardBuilder;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = widget.platform;
    // A kind with no platform has nothing to resolve; treat it as a missing
    // card so it still renders the placeholder-with-menu and stays removable.
    final cardState = platform == null
        ? const AsyncData<GameCard?>(null)
        : ref.watch(ownerCardProvider(platform));
    return AsyncValueWidget<GameCard?>(
      value: cardState,
      onRetry: platform == null
          ? null // nothing to retry for a kind that has no platform
          : () => ref.invalidate(ownerCardProvider(platform)),
      // Soft resolution: a missing card (null) renders a placeholder, not an
      // error, and keeps the options menu reachable so the widget stays
      // manageable.
      data: (card) => Stack(
        children: [
          // A hidden widget stays in the grid dimmed so its "Show" action
          // remains reachable; the menu itself stays at full opacity.
          Opacity(
            opacity: widget.isEnabled ? 1.0 : 0.5,
            child: card == null
                ? _PlaceholderTile(
                    key: Key('profileWidgetPlaceholder_${widget.id}'),
                  )
                : cardBuilder(card),
          ),
          Positioned(
            top: AppSpacing.xs,
            right: AppSpacing.xs,
            child: _WidgetOptionsMenu(
              widget: widget,
              canMoveUp: canMoveUp,
              canMoveDown: canMoveDown,
              onMoveUp: onMoveUp,
              onMoveDown: onMoveDown,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fills a tile's allotted span when a platform widget's card is not available,
/// so the cell is intentional (not a blank reserved hole) and the widget's
/// options menu stays reachable for removal.
class _PlaceholderTile extends StatelessWidget {
  const _PlaceholderTile({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      alignment: Alignment.center,
      child: Text(
        l10n.profileWidgetCardUnavailable,
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

enum _WidgetMenuAction { hide, show, remove, moveUp, moveDown }

class _WidgetOptionsMenu extends ConsumerWidget {
  const _WidgetOptionsMenu({
    required this.widget,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final ProfileWidget widget;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(profileWidgetsControllerProvider.notifier);

    return PopupMenuButton<Object>(
      key: Key('profileWidgetMenu_${widget.id}'),
      icon: const Icon(Icons.more_vert),
      tooltip: l10n.profileWidgetOptions,
      onSelected: (value) {
        switch (value) {
          case ProfileWidgetSize size:
            controller.resize(widget.id, size);
          case _WidgetMenuAction.hide:
            controller.toggle(widget.id, false);
          case _WidgetMenuAction.show:
            controller.toggle(widget.id, true);
          case _WidgetMenuAction.remove:
            controller.remove(widget.id);
          case _WidgetMenuAction.moveUp:
            onMoveUp();
          case _WidgetMenuAction.moveDown:
            onMoveDown();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(enabled: false, child: Text(l10n.profileWidgetResize)),
        PopupMenuItem(
          value: ProfileWidgetSize.small,
          child: Text(l10n.profileWidgetSizeSmall),
        ),
        PopupMenuItem(
          value: ProfileWidgetSize.wide,
          child: Text(l10n.profileWidgetSizeWide),
        ),
        PopupMenuItem(
          value: ProfileWidgetSize.large,
          child: Text(l10n.profileWidgetSizeLarge),
        ),
        const PopupMenuDivider(),
        if (canMoveUp)
          PopupMenuItem(
            value: _WidgetMenuAction.moveUp,
            child: Text(l10n.profileWidgetMoveUp),
          ),
        if (canMoveDown)
          PopupMenuItem(
            value: _WidgetMenuAction.moveDown,
            child: Text(l10n.profileWidgetMoveDown),
          ),
        if (widget.isEnabled)
          PopupMenuItem(
            value: _WidgetMenuAction.hide,
            child: Text(l10n.profileWidgetHide),
          )
        else
          PopupMenuItem(
            value: _WidgetMenuAction.show,
            child: Text(l10n.profileWidgetShow),
          ),
        PopupMenuItem(
          value: _WidgetMenuAction.remove,
          child: Text(l10n.profileWidgetRemove),
        ),
      ],
    );
  }
}
