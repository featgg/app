import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../connections/domain/connection.dart';
import '../../connections/domain/platform_descriptor.dart';
import '../domain/data_menu_catalog.dart';
import '../domain/profile_widget.dart';
import '../domain/template_catalog.dart';
import '../domain/template_value_resolver.dart';
import 'data_menu_labels.dart';
import 'featured_platform_provider.dart';
import 'profile_owner_cards_provider.dart';
import 'profile_widgets_controller.dart';
import 'template_labels.dart';

/// Opens the template picker as a modal bottom sheet. On pick, it adds the
/// chosen template at [nextPosition] (max-position+1, the same rule the platform
/// add uses) through the existing host-observed controller and closes.
Future<void> showTemplatePicker(BuildContext context, int nextPosition) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TemplatePickerSheet(nextPosition: nextPosition),
    );

/// Opens the slot chooser for a template [widget]: a list of the template's
/// slots, each showing its current fill (or "not set") and opening the
/// per-slot fill flow on tap. The template id soft-resolves — an unknown id
/// closes immediately with nothing to choose.
Future<void> showTemplateSlots(BuildContext context, ProfileWidget widget) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SlotChooserSheet(widget: widget),
    );

/// Opens the slot-fill flow for one [slot] of a template [widget]: a list of the
/// data-menu items of the slot's category whose platform the owner has
/// connected (reusing the data-menu category filter + connected-platforms
/// gating). On pick, it persists the fill through the controller and closes.
Future<void> showTemplateSlotFill(
  BuildContext context,
  ProfileWidget widget,
  TemplateSlot slot,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _SlotFillSheet(widget: widget, slot: slot),
);

class _TemplatePickerSheet extends ConsumerWidget {
  const _TemplatePickerSheet({required this.nextPosition});

  final int nextPosition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.templateChooseTitle,
              key: const Key('templatePickerTitle'),
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final definition in templateCatalog)
              ListTile(
                key: Key('templatePickerItem_${definition.id}'),
                title: Text(
                  templateTitleLabel(l10n, definition.titleKey) ??
                      definition.id,
                ),
                onTap: () {
                  ref
                      .read(profileWidgetsControllerProvider.notifier)
                      .addTemplate(
                        templateId: definition.id,
                        position: nextPosition,
                        size: ProfileWidgetSize.small,
                      );
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SlotChooserSheet extends ConsumerWidget {
  const _SlotChooserSheet({required this.widget});

  final ProfileWidget widget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final definition = templateDefinitionById(widget.templateFill.templateId);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              definition == null
                  ? l10n.templateFillSlots
                  : templateTitleLabel(l10n, definition.titleKey) ??
                        l10n.templateFillSlots,
              key: const Key('slotChooserTitle'),
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (definition != null)
              for (final slot in definition.slots)
                ListTile(
                  key: Key('slotChooserItem_${slot.id}'),
                  title: Text(
                    templateSlotLabel(l10n, slot.labelKey) ?? slot.labelKey,
                  ),
                  subtitle: Text(_subtitle(l10n, slot.id)),
                  onTap: () {
                    Navigator.of(context).pop();
                    showTemplateSlotFill(context, widget, slot);
                  },
                ),
          ],
        ),
      ),
    );
  }

  String _subtitle(AppLocalizations l10n, String slotId) {
    final itemId = widget.templateFill.itemIdFor(slotId);
    if (itemId == null) return l10n.templateSlotEmpty;
    for (final item in dataMenuCatalog) {
      if (item.id == itemId) {
        return dataMenuItemLabel(l10n, item.labelKey) ?? item.id;
      }
    }
    return l10n.templateSlotEmpty;
  }
}

class _SlotFillSheet extends ConsumerWidget {
  const _SlotFillSheet({required this.widget, required this.slot});

  final ProfileWidget widget;
  final TemplateSlot slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final connectedState = ref.watch(connectedPlatformsProvider);
    // While a save is in flight, disable the slot choices so a second fill
    // cannot be issued — serializing the writes (at most one in flight) so a
    // rapid second pick, taken before the read provider refreshes, cannot
    // overwrite the slot just saved. Mirrors the data menu sheet's gating.
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
    // Items of the slot's category whose platform the owner has connected — the
    // same gating the data menu applies.
    final items = [
      for (final item in dataMenuCatalog)
        if (item.category == slot.category &&
            connectedSet.contains(item.platform))
          item,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          templateSlotLabel(l10n, slot.labelKey) ?? slot.labelKey,
          key: const Key('slotFillTitle'),
          style: textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (items.isEmpty)
          Text(
            l10n.dataMenuConnectFirst,
            key: const Key('slotFillConnectFirst'),
            style: textTheme.bodyMedium,
          )
        else
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in items)
                    _SlotFillItem(
                      widget: widget,
                      slot: slot,
                      item: item,
                      saving: saving,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// One pickable item in the slot-fill sheet, annotated with a muted "no data
/// yet" trailing label when the item's platform card currently yields no value
/// for this slot. It watches `ownerCardProvider(item.platform)` itself, so the
/// annotation is derived (never stored) and scoped to the item whose card
/// changed. The annotation never disables the item (a platform may sync later —
/// only the in-flight-save gate disables). While the card is still loading and
/// has no value the item is left unannotated, so the sheet never asserts "no
/// data" mid-load.
class _SlotFillItem extends ConsumerWidget {
  const _SlotFillItem({
    required this.widget,
    required this.slot,
    required this.item,
    required this.saving,
  });

  final ProfileWidget widget;
  final TemplateSlot slot;
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

    return ListTile(
      key: Key('slotFillItem_${item.id}'),
      title: Text(dataMenuItemLabel(l10n, item.labelKey) ?? item.id),
      subtitle: Text(
        platformDescriptors[item.platform]?.displayName ?? item.platform.name,
      ),
      trailing: showNoData
          ? Text(
              l10n.templateSlotNoData,
              key: Key('slotFillNoData_${item.id}'),
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      onTap: saving
          ? null
          : () {
              ref
                  .read(profileWidgetsControllerProvider.notifier)
                  .setTemplateSlot(
                    widgetId: widget.id,
                    slotId: slot.id,
                    itemId: item.id,
                  );
              Navigator.of(context).pop();
            },
    );
  }
}
