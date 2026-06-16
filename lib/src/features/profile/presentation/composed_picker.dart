import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../connections/domain/connection.dart';
import '../../connections/domain/platform_descriptor.dart';
import '../domain/data_menu_catalog.dart';
import '../domain/profile_widget.dart';
import '../domain/template_value_resolver.dart';
import 'data_menu_labels.dart';
import 'featured_platform_provider.dart';
import 'profile_owner_cards_provider.dart';
import 'profile_widgets_controller.dart';

/// Opens the composed-card item picker for [widget]: the data-menu catalog
/// grouped by the five semantic categories and gated to connected platforms,
/// each item a toggle that adds/removes it from the composed card's freely
/// picked set. Each toggle persists through the widget's `settings`.
Future<void> showComposedItemPicker(
  BuildContext context,
  ProfileWidget widget,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _ComposedItemSheet(profileWidget: widget),
);

class _ComposedItemSheet extends ConsumerStatefulWidget {
  const _ComposedItemSheet({required this.profileWidget});

  final ProfileWidget profileWidget;

  @override
  ConsumerState<_ComposedItemSheet> createState() => _ComposedItemSheetState();
}

class _ComposedItemSheetState extends ConsumerState<_ComposedItemSheet> {
  /// Null means "All"; otherwise the platform the chip row narrows to.
  Platform? _platformFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final connectedState = ref.watch(connectedPlatformsProvider);
    // While a save is in flight, disable the item toggles so a second write
    // cannot be issued — serializing the writes (at most one in flight) so a
    // rapid second pick, taken before the read provider refreshes, cannot
    // overwrite the set just saved. Mirrors the slot-fill sheet's gating.
    final saving = ref.watch(profileWidgetsControllerProvider).isLoading;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: AsyncValueWidget<List<Platform>>(
          value: connectedState,
          onRetry: () => ref.invalidate(connectedPlatformsProvider),
          data: (connected) =>
              _content(l10n, textTheme, connected.toSet(), saving),
        ),
      ),
    );
  }

  Widget _content(
    AppLocalizations l10n,
    TextTheme textTheme,
    Set<Platform> connectedSet,
    bool saving,
  ) {
    // Only catalog platforms the owner has actually connected are offered — the
    // same gating the data menu applies.
    final catalogPlatforms = {
      for (final item in dataMenuCatalog)
        if (connectedSet.contains(item.platform)) item.platform,
    }.toList();

    if (catalogPlatforms.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(l10n, textTheme),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.dataMenuConnectFirst,
            key: const Key('composedConnectFirst'),
            style: textTheme.bodyMedium,
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(l10n, textTheme),
        const SizedBox(height: AppSpacing.sm),
        _PlatformFilterRow(
          platforms: catalogPlatforms,
          selected: _platformFilter,
          onSelected: (p) => setState(() => _platformFilter = p),
        ),
        const SizedBox(height: AppSpacing.sm),
        // The catalog is small (≤ ~15 rows); a non-lazy scroll view keeps every
        // category section in the tree so none is dropped off-screen.
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final category in DataMenuCategory.values)
                  ..._categorySection(
                    l10n,
                    textTheme,
                    category,
                    connectedSet,
                    saving,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(AppLocalizations l10n, TextTheme textTheme) => Text(
    l10n.composedChooseTitle,
    key: const Key('composedChooseTitle'),
    style: textTheme.titleLarge,
  );

  List<Widget> _categorySection(
    AppLocalizations l10n,
    TextTheme textTheme,
    DataMenuCategory category,
    Set<Platform> connectedSet,
    bool saving,
  ) {
    final items = [
      for (final item in dataMenuCatalog)
        if (item.category == category &&
            connectedSet.contains(item.platform) &&
            (_platformFilter == null || item.platform == _platformFilter))
          item,
    ];
    if (items.isEmpty) return const [];
    return [
      Padding(
        key: Key('composedCategory_${category.name}'),
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Text(
          dataMenuCategoryLabel(l10n, category),
          style: textTheme.titleSmall,
        ),
      ),
      for (final item in items)
        _ComposedItem(
          profileWidget: widget.profileWidget,
          item: item,
          saving: saving,
        ),
    ];
  }
}

/// One pickable item in the composed-card picker, shown as a toggle reflecting
/// its current membership in the composed set, and annotated with a muted "no
/// data yet" trailing label when the item's platform card currently yields no
/// value. It watches `ownerCardProvider(item.platform)` itself, so the
/// annotation is derived (never stored) and scoped to the item whose card
/// changed. The annotation never disables the item (a platform may sync later —
/// only the in-flight-save gate disables). While the card is still loading and
/// has no value the item is left unannotated, so the sheet never asserts "no
/// data" mid-load.
class _ComposedItem extends ConsumerWidget {
  const _ComposedItem({
    required this.profileWidget,
    required this.item,
    required this.saving,
  });

  final ProfileWidget profileWidget;
  final DataMenuItem item;
  final bool saving;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final cardState = ref.watch(ownerCardProvider(item.platform));
    final loadingUnknown = cardState.isLoading && !cardState.hasValue;
    final resolved = cardState.hasError
        ? null
        : resolveSlot(item.id, cardState.value);
    final showNoData = !loadingUnknown && resolved == null;

    return SwitchListTile(
      key: Key('composedItem_${item.id}'),
      value: profileWidget.composedFill.contains(item.id),
      onChanged: saving
          ? null
          : (_) => ref
                .read(profileWidgetsControllerProvider.notifier)
                .toggleComposedItem(
                  widgetId: profileWidget.id,
                  itemId: item.id,
                ),
      title: Text(dataMenuItemLabel(l10n, item.labelKey) ?? item.id),
      subtitle: showNoData
          ? Text(
              l10n.templateSlotNoData,
              key: Key('composedNoData_${item.id}'),
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : Text(
              platformDescriptors[item.platform]?.displayName ??
                  item.platform.name,
            ),
    );
  }
}

/// Platform filter chips: "All" plus one per connected catalog platform.
class _PlatformFilterRow extends StatelessWidget {
  const _PlatformFilterRow({
    required this.platforms,
    required this.selected,
    required this.onSelected,
  });

  final List<Platform> platforms;
  final Platform? selected;
  final ValueChanged<Platform?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: AppSpacing.xs,
      children: [
        ChoiceChip(
          key: const Key('composedFilter_all'),
          label: Text(l10n.dataMenuFilterAll),
          selected: selected == null,
          onSelected: (_) => onSelected(null),
        ),
        for (final platform in platforms)
          ChoiceChip(
            key: Key('composedFilter_${platform.name}'),
            label: Text(
              platformDescriptors[platform]?.displayName ?? platform.name,
            ),
            selected: selected == platform,
            onSelected: (_) => onSelected(platform),
          ),
      ],
    );
  }
}
