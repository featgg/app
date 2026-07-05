import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../connections/domain/game_card.dart';
import '../domain/profile_widget.dart';
import '../domain/showcase_selection.dart';
import '../domain/showcase_value_resolver.dart';
import 'collection_card_view.dart';
import 'composed_card_view.dart';
import 'composed_picker.dart';
import 'data_menu_screen.dart';
import 'profile_owner_cards_provider.dart';
import 'profile_screen.dart';
import 'profile_widgets_controller.dart';
import 'profile_widgets_layout.dart';
import 'showcase_card_view.dart';
import 'template_card_view.dart';
import 'template_picker.dart';

/// Renders the owner's profile widgets through [ProfileWidgetsFlow]: a single
/// full-width column on compact, an auto-packing multi-column grid above the
/// medium breakpoint (each tile at its natural content height — the connections
/// card is designed to render full width with content-driven height). Each
/// [ProfileWidgetKind.platform] widget renders its card via the
/// composition-root-injected [cardBuilder]; a widget whose card is not
/// available renders a placeholder that keeps its options menu reachable, so
/// the widget stays manageable (it is never shown as an error tile).
///
/// Every widget renders regardless of `is_enabled`, so no row is stuck.
///
/// The flow is non-scrolling and is composed inside the profile screen's own
/// scroll view. The per-tile options menu drives the
/// [ProfileWidgetsController] (remove / reorder).
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

    return ProfileWidgetsFlow(
      tiles: [
        for (var i = 0; i < ordered.length; i++)
          ProfileWidgetTile(
            widget: ordered[i],
            child: _WidgetTile(
              key: Key('profileWidgetTile_${ordered[i].id}'),
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
    super.key,
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
    // A template widget composes its own value rows (each watching its slot's
    // card) and is never resolved through the injected platform cardBuilder.
    if (widget.kind == ProfileWidgetKind.template) {
      return Stack(
        children: [
          ClipRect(child: TemplateCardView(widget: widget)),
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
      );
    }

    // A composed widget composes its own value rows from the owner's freely
    // picked items (each watching its item's card) and is never resolved
    // through the injected platform cardBuilder.
    if (widget.kind == ProfileWidgetKind.composed) {
      return Stack(
        children: [
          ClipRect(child: ComposedCardView(widget: widget)),
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
      );
    }

    // A showcase widget resolves its own single-game art card and is never
    // resolved through the injected platform cardBuilder.
    if (widget.kind == ProfileWidgetKind.showcase) {
      return Stack(
        children: [
          ClipRect(child: ShowcaseCardView(widget: widget)),
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
      );
    }

    // A collection widget resolves its own multi-game panorama and is never
    // resolved through the injected platform cardBuilder.
    if (widget.kind == ProfileWidgetKind.collection) {
      return Stack(
        children: [
          ClipRect(child: CollectionCardView(widget: widget)),
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
      );
    }

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
          // ClipRect bounds the child's paint to the tile box so an
          // unexpectedly-oversized card degrades by clipping rather than
          // throwing a fatal RenderFlex overflow; under the full-width
          // content-height layout the card fits, so it is a no-op in the
          // happy path.
          ClipRect(
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

/// Renders in place of a platform widget's card when it is not available, so
/// the tile is intentional (not a blank hole) and the widget's options menu
/// stays reachable for removal.
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

enum _WidgetMenuAction {
  customizeData,
  fillSlots,
  editItems,
  resizeSmall,
  resizeWide,
  resizeLarge,
  heroHours,
  heroAchievements,
  remove,
  moveUp,
  moveDown,
}

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

    // A resize rewrites the widget's own settings sub-object so its selection
    // survives the write: a showcase carries its single game, a collection its
    // games + title.
    void resizeTo(ProfileWidgetSize size) {
      if (widget.kind == ProfileWidgetKind.collection) {
        controller.resizeCollection(
          widget.id,
          size,
          widget.collectionSelection,
        );
      } else {
        controller.resizeShowcase(widget.id, size, widget.showcaseSelection);
      }
    }

    // The achievements hero is offered only when the showcased game currently
    // carries a renderable achievement pair; otherwise only the hours hero
    // exists, so no in-card stat choice is surfaced.
    var achievementsAvailable = false;
    if (widget.kind == ProfileWidgetKind.showcase && widget.platform != null) {
      final cardState = ref.watch(ownerCardProvider(widget.platform!));
      final data = cardState.hasError ? null : cardState.value?.data;
      final steam = data is SteamCardData ? data : null;
      achievementsAvailable = showcaseAchievementsAvailable(
        steam,
        widget.showcaseSelection,
      );
    }

    return PopupMenuButton<_WidgetMenuAction>(
      key: Key('profileWidgetMenu_${widget.id}'),
      icon: _MenuGlyph(widgetId: widget.id),
      tooltip: l10n.profileWidgetOptions,
      onSelected: (value) {
        switch (value) {
          case _WidgetMenuAction.customizeData:
            showDataMenu(context, widget);
          case _WidgetMenuAction.fillSlots:
            showTemplateSlots(context, widget);
          case _WidgetMenuAction.editItems:
            showComposedItemPicker(context, widget);
          case _WidgetMenuAction.resizeSmall:
            resizeTo(ProfileWidgetSize.small);
          case _WidgetMenuAction.resizeWide:
            resizeTo(ProfileWidgetSize.wide);
          case _WidgetMenuAction.resizeLarge:
            resizeTo(ProfileWidgetSize.large);
          case _WidgetMenuAction.heroHours:
            controller.setShowcaseHero(
              widget.id,
              widget.size,
              widget.showcaseSelection.copyWith(hero: ShowcaseHeroStat.hours),
            );
          case _WidgetMenuAction.heroAchievements:
            controller.setShowcaseHero(
              widget.id,
              widget.size,
              widget.showcaseSelection.copyWith(
                hero: ShowcaseHeroStat.achievements,
              ),
            );
          case _WidgetMenuAction.remove:
            controller.remove(widget.id);
          case _WidgetMenuAction.moveUp:
            onMoveUp();
          case _WidgetMenuAction.moveDown:
            onMoveDown();
        }
      },
      itemBuilder: (context) {
        PopupMenuItem<_WidgetMenuAction> selectable(
          _WidgetMenuAction value,
          String label,
          bool selected,
        ) => PopupMenuItem(
          value: value,
          padding: EdgeInsets.zero,
          child: _SelectableMenuRow(label: label, selected: selected),
        );

        final sections = <List<PopupMenuEntry<_WidgetMenuAction>>>[];

        // Customize: a template widget fills its slots, a composed widget edits
        // its freely picked items, and a platform widget customizes which stats
        // its card surfaces. The three are mutually exclusive so each kind shows
        // exactly one customize entry; the showcase has none.
        final customize = <PopupMenuEntry<_WidgetMenuAction>>[
          if (widget.kind == ProfileWidgetKind.template)
            PopupMenuItem(
              value: _WidgetMenuAction.fillSlots,
              child: Text(l10n.templateFillSlots),
            )
          else if (widget.kind == ProfileWidgetKind.composed)
            PopupMenuItem(
              value: _WidgetMenuAction.editItems,
              child: Text(l10n.composedEditItems),
            )
          else if (widget.kind == ProfileWidgetKind.platform)
            PopupMenuItem(
              value: _WidgetMenuAction.customizeData,
              child: Text(l10n.profileWidgetCustomizeData),
            ),
        ];
        if (customize.isNotEmpty) sections.add(customize);

        // A showcase or collection widget surfaces its size on the card itself:
        // pick a footprint and the card re-renders at that size, the active size
        // shown by row highlight. Scoped to these two art cards — the other
        // kinds' size is not yet in-card editable.
        if (widget.kind == ProfileWidgetKind.showcase ||
            widget.kind == ProfileWidgetKind.collection) {
          sections.add([
            selectable(
              _WidgetMenuAction.resizeSmall,
              l10n.profileWidgetSizeSmall,
              widget.size == ProfileWidgetSize.small,
            ),
            selectable(
              _WidgetMenuAction.resizeWide,
              l10n.profileWidgetSizeWide,
              widget.size == ProfileWidgetSize.wide,
            ),
            selectable(
              _WidgetMenuAction.resizeLarge,
              l10n.profileWidgetSizeLarge,
              widget.size == ProfileWidgetSize.large,
            ),
          ]);
        }

        // The hero-stat choice appears only when the showcased game currently
        // carries the achievement pair — so the option is offered only when
        // there is a real choice between hours and achievements; the active hero
        // is shown by row highlight.
        if (widget.kind == ProfileWidgetKind.showcase &&
            achievementsAvailable) {
          final hero = widget.showcaseSelection.hero;
          sections.add([
            selectable(
              _WidgetMenuAction.heroHours,
              l10n.showcaseHeroHours,
              hero == ShowcaseHeroStat.hours,
            ),
            selectable(
              _WidgetMenuAction.heroAchievements,
              l10n.showcaseHeroAchievements,
              hero == ShowcaseHeroStat.achievements,
            ),
          ]);
        }

        // Actions: always at least Remove; move gating unchanged.
        sections.add([
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
          PopupMenuItem(
            value: _WidgetMenuAction.remove,
            child: Text(l10n.profileWidgetRemove),
          ),
        ]);

        // A skipped (empty) section emits no divider, so there is never a
        // leading divider before an absent hero section.
        final items = <PopupMenuEntry<_WidgetMenuAction>>[];
        for (final section in sections) {
          if (section.isEmpty) continue;
          if (items.isNotEmpty) items.add(const PopupMenuDivider());
          items.addAll(section);
        }
        return items;
      },
    );
  }
}

/// The options-menu glyph on a semi-opaque circular scrim so it keeps
/// guaranteed contrast on any tile surface — full-bleed showcase art or a plain
/// surface tile — the same on-art-light idea the showcase text uses on its
/// scrim in both themes.
class _MenuGlyph extends StatelessWidget {
  const _MenuGlyph({required this.widgetId});

  final String widgetId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Always-light on the dark scrim in both themes: dark theme's onSurface is
    // already light; light theme needs the inverse role or the glyph goes dark.
    final glyph = scheme.brightness == Brightness.dark
        ? scheme.onSurface
        : scheme.onInverseSurface;
    return DecoratedBox(
      key: Key('profileWidgetMenuIcon_$widgetId'),
      decoration: BoxDecoration(
        color: scheme.scrim.withValues(alpha: 0.45),
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Icon(Icons.more_vert, color: glyph),
      ),
    );
  }
}

/// A menu row that marks the active choice by highlighting the whole row (a
/// filled container + emphasized label) instead of a checkmark, so every row —
/// selected or not — keeps the same left text origin and nothing shifts. Used
/// for the mutually-exclusive size and hero choices.
class _SelectableMenuRow extends StatelessWidget {
  const _SelectableMenuRow({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Container(
            constraints: const BoxConstraints(
              minHeight: kMinInteractiveDimension,
            ),
            alignment: AlignmentDirectional.centerStart,
            // Match PopupMenuItem's default 16 inset so selectable rows align
            // horizontally with the plain action rows below.
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            color: selected ? scheme.secondaryContainer : null,
            child: Text(
              label,
              // Only color+weight are overridden; size/family inherit the menu's
              // default text style so selectable rows match the plain rows.
              style: TextStyle(
                color: selected ? scheme.onSecondaryContainer : null,
                fontWeight: selected ? AppTypography.semiBold : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
