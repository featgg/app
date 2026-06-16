import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../connections/domain/platform_descriptor.dart';
import '../domain/data_menu_catalog.dart';
import '../domain/profile_widget.dart';
import '../domain/template_value_resolver.dart';
import 'profile_owner_cards_provider.dart';

/// Profile-owned renderer for a [ProfileWidgetKind.composed] widget. Renders one
/// row per RESOLVED picked item, in the owner's pick order: the bound platform
/// on the left and its resolved value on the right. A picked item soft-omits
/// (contributes no row) whenever it does not currently resolve to a value —
/// card null, still loading, errored, the stat absent, or a non-scalar pointer
/// — so the card never asserts "no data" while an item is loading and never
/// shows an empty row. When no picked item resolves (or none is picked), it
/// renders the empty placeholder so the tile stays intentional (the grid keeps
/// the options menu reachable).
///
/// The card carries no owner-only affordance: it renders identically for the
/// owner and a future visitor render path, so it has no placeholder/"—" row.
///
/// Each picked item watches `ownerCardProvider(item.platform)` itself, so the
/// renderer needs no injected card builder. An item whose card is loading or
/// errored simply omits its row — it never errors the whole card.
class ComposedCardView extends ConsumerWidget {
  const ComposedCardView({super.key, required this.widget});

  final ProfileWidget widget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final rows = <Widget>[];
    for (final itemId in widget.composedFill.itemIds) {
      final item = _dataMenuItemById(itemId);
      if (item == null) continue; // a stale/unknown token soft-resolves away
      // Soft-omit: the value is null while the card loads, on error, or when
      // the card lacks the stat — the row only appears once a value resolves,
      // so the card never shows an empty/loading row. One item's miss never
      // errors the card.
      final cardState = ref.watch(ownerCardProvider(item.platform));
      final resolved = cardState.hasError
          ? null
          : resolveSlot(itemId, cardState.value);
      if (resolved == null) continue;
      final platformName =
          platformDescriptors[item.platform]?.displayName ?? item.platform.name;
      rows.add(
        Padding(
          key: Key('composedItemRow_${widget.id}_$itemId'),
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  platformName,
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

    return Container(
      key: Key('composedCard_${widget.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rows.isEmpty)
            Padding(
              key: Key('composedEmpty_${widget.id}'),
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                l10n.composedEmpty,
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
