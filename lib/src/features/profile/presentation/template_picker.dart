import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../connections/domain/connection.dart';
import '../../connections/domain/platform_descriptor.dart';
import '../domain/data_menu_catalog.dart';
import '../domain/profile_widget.dart';
import '../domain/template_catalog.dart';
import 'data_menu_labels.dart';
import 'featured_platform_provider.dart';
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: AsyncValueWidget<List<Platform>>(
          value: connectedState,
          onRetry: () => ref.invalidate(connectedPlatformsProvider),
          data: (connected) =>
              _content(context, ref, l10n, textTheme, connected.toSet()),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    TextTheme textTheme,
    Set<Platform> connectedSet,
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
                    ListTile(
                      key: Key('slotFillItem_${item.id}'),
                      title: Text(
                        dataMenuItemLabel(l10n, item.labelKey) ?? item.id,
                      ),
                      subtitle: Text(
                        platformDescriptors[item.platform]?.displayName ??
                            item.platform.name,
                      ),
                      onTap: () {
                        ref
                            .read(profileWidgetsControllerProvider.notifier)
                            .setTemplateFill(
                              widget,
                              widget.templateFill.withSlot(slot.id, item.id),
                            );
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
