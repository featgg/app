import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../domain/data_menu_catalog.dart';
import '../domain/profile_widget.dart';
import '../domain/template_catalog.dart';
import '../domain/template_value_resolver.dart';
import 'profile_owner_cards_provider.dart';
import 'template_labels.dart';

/// Profile-owned renderer for a [ProfileWidgetKind.template] widget. Renders the
/// template title and one value row per filled slot that resolves to a value;
/// empty or unresolvable slots are soft-omitted. When the template id is unknown
/// or every slot is empty/unresolvable, it renders the all-empty placeholder so
/// the tile stays intentional (the grid keeps the options menu reachable).
///
/// Each filled slot watches `ownerCardProvider(item.platform)` itself, so the
/// renderer needs no injected card builder. A single slot whose card is loading
/// or errored simply does not contribute a row — it never errors the whole card.
class TemplateCardView extends ConsumerWidget {
  const TemplateCardView({super.key, required this.widget});

  final ProfileWidget widget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final fill = widget.templateFill;
    final definition = templateDefinitionById(fill.templateId);

    final rows = <Widget>[];
    if (definition != null) {
      for (final slot in definition.slots) {
        final itemId = fill.itemIdFor(slot.id);
        if (itemId == null) continue;
        final item = _dataMenuItemById(itemId);
        if (item == null) continue;
        // value is the loaded card, or null while loading / on error — both fold
        // to a soft-omit so one slot's load or failure never errors the card.
        final cardState = ref.watch(ownerCardProvider(item.platform));
        final resolved = resolveSlot(itemId, cardState.value);
        if (resolved == null) continue;
        rows.add(
          Padding(
            key: Key('templateSlotRow_${widget.id}_${slot.id}'),
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    templateSlotLabel(l10n, slot.labelKey) ?? slot.labelKey,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _displayValue(resolved),
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.end,
                ),
              ],
            ),
          ),
        );
      }
    }

    final title = definition == null
        ? null
        : templateTitleLabel(l10n, definition.titleKey);

    return Container(
      key: Key('templateCard_${widget.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) Text(title, style: textTheme.titleMedium),
          if (rows.isEmpty)
            Padding(
              key: Key('templateEmpty_${widget.id}'),
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                l10n.templateEmpty,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...rows,
        ],
      ),
    );
  }
}

DataMenuItem? _dataMenuItemById(String id) {
  for (final item in dataMenuCatalog) {
    if (item.id == id) return item;
  }
  return null;
}

/// Stringifies the resolved value for its row, appending the unit token when
/// present. The value is already either a raw scalar (envelope stat) or a
/// pre-composed string (data block), so a plain `toString` is the display.
String _displayValue(ResolvedSlotValue resolved) {
  final value = resolved.value.toString();
  final unit = resolved.unit;
  return unit == null ? value : '$value $unit';
}
