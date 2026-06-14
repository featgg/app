import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../connections/domain/connection.dart';
import '../../connections/domain/platform_descriptor.dart';
import '../domain/data_menu_catalog.dart';
import '../domain/data_menu_selection.dart';
import '../domain/profile_widget.dart';
import 'data_menu_controller.dart';
import 'data_menu_labels.dart';
import 'featured_platform_provider.dart';

/// Opens the data menu for [widget] as a modal bottom sheet. The owner browses
/// the catalog grouped by the five semantic categories, optionally filters by a
/// connected platform, and toggles which items the card surfaces; each toggle
/// persists through the widget's `settings`.
Future<void> showDataMenu(BuildContext context, ProfileWidget widget) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DataMenuSheet(widget: widget),
    );

/// The data menu body. Watches the owner's connected platforms and shows only
/// the catalog items whose platform is connected; rendering by category iterates
/// [DataMenuCategory.values] then filters [dataMenuCatalog], so a new item or
/// category needs no change here.
class DataMenuSheet extends ConsumerStatefulWidget {
  const DataMenuSheet({super.key, required this.widget});

  final ProfileWidget widget;

  @override
  ConsumerState<DataMenuSheet> createState() => _DataMenuSheetState();
}

class _DataMenuSheetState extends ConsumerState<DataMenuSheet> {
  /// Ephemeral edit buffer for the open sheet; the persisted truth is the
  /// controller + read provider, re-read on invalidate after each write.
  late DataMenuSelection _selection = widget.widget.selection;

  /// Null means "All"; otherwise the platform the chip row narrows to.
  Platform? _platformFilter;

  void _toggle(String id) {
    final next = _selection.toggle(id);
    setState(() => _selection = next);
    ref
        .read(dataMenuControllerProvider.notifier)
        .setSelection(widget.widget, next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final connectedState = ref.watch(connectedPlatformsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: AsyncValueWidget<List<Platform>>(
          value: connectedState,
          onRetry: () => ref.invalidate(connectedPlatformsProvider),
          data: (connected) => _content(context, l10n, textTheme, connected),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    AppLocalizations l10n,
    TextTheme textTheme,
    List<Platform> connected,
  ) {
    // Only catalog platforms the owner has actually connected are offered.
    final connectedSet = connected.toSet();
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
            key: const Key('dataMenuConnectFirst'),
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
                  ..._categorySection(l10n, textTheme, category, connectedSet),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(AppLocalizations l10n, TextTheme textTheme) => Text(
    l10n.dataMenuTitle,
    key: const Key('dataMenuTitle'),
    style: textTheme.titleLarge,
  );

  List<Widget> _categorySection(
    AppLocalizations l10n,
    TextTheme textTheme,
    DataMenuCategory category,
    Set<Platform> connectedSet,
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
        key: Key('dataMenuCategory_${category.name}'),
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Text(
          dataMenuCategoryLabel(l10n, category),
          style: textTheme.titleSmall,
        ),
      ),
      for (final item in items)
        SwitchListTile(
          key: Key('dataMenuItem_${item.id}'),
          value: _selection.contains(item.id),
          onChanged: (_) => _toggle(item.id),
          title: Text(dataMenuItemLabel(l10n, item.labelKey) ?? item.id),
        ),
    ];
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
          key: const Key('dataMenuFilter_all'),
          label: Text(l10n.dataMenuFilterAll),
          selected: selected == null,
          onSelected: (_) => onSelected(null),
        ),
        for (final platform in platforms)
          ChoiceChip(
            key: Key('dataMenuFilter_${platform.name}'),
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
