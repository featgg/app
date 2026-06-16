import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../connections/domain/platform_descriptor.dart';
import '../domain/data_menu_catalog.dart';
import '../domain/profile_widget.dart';
import '../domain/template_catalog.dart';
import '../domain/template_value_resolver.dart';
import 'profile_owner_cards_provider.dart';
import 'template_labels.dart';

/// Profile-owned renderer for a [ProfileWidgetKind.template] widget. Renders the
/// template title and one row per RESOLVED slot: the bound platform on the left
/// and its resolved value on the right. A filled slot soft-omits (contributes no
/// row) whenever it does not currently resolve to a value — card null, still
/// loading, errored, the stat absent, or a non-scalar pointer — so the card
/// never asserts "no data" while a slot is loading and never shows an empty row.
/// When the template id is unknown or no slot resolves, it renders the all-empty
/// placeholder so the tile stays intentional (the grid keeps the options menu
/// reachable).
///
/// The card carries no owner-only affordance: it renders identically for the
/// owner and a future visitor render path, so it has no placeholder/"—" row.
/// Owner feedback that a filled slot has no value yet lives in the (owner-only)
/// slot-fill sheet, not here.
///
/// Each filled slot watches `ownerCardProvider(item.platform)` itself, so the
/// renderer needs no injected card builder. A slot whose card is loading or
/// errored simply omits its row — it never errors the whole card.
class TemplateCardView extends ConsumerWidget {
  const TemplateCardView({
    super.key,
    required this.widget,
    this.cardSource,
    this.showEmptyPlaceholder = true,
  });

  final ProfileWidget widget;

  /// Where each row resolves its card. Null → the owner's own card
  /// ([ownerCardProvider]); the visitor render injects a public source so the
  /// same view renders a profile's PUBLIC cards.
  final CardSource? cardSource;

  /// When no slot resolves, the owner sees a "fill a slot" placeholder so the
  /// card stays actionable. A visitor has no such action, so the visitor render
  /// passes false to omit an empty card entirely instead of showing it.
  final bool showEmptyPlaceholder;

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
        if (itemId == null) continue; // an unfilled slot contributes no row
        final item = _dataMenuItemById(itemId);
        if (item == null) continue; // a stale/unknown token soft-resolves away
        // Soft-omit: the value is null while the card loads, on error, or when
        // the card lacks the stat — the row only appears once a value resolves,
        // so the card never shows an empty/loading row. One slot's miss never
        // errors the card.
        final source = cardSource;
        final cardState = source == null
            ? ref.watch(ownerCardProvider(item.platform))
            : ref.watch(source(item.platform));
        final resolved = resolveSlot(itemId, cardState.value);
        if (resolved == null) continue;
        final platformName =
            platformDescriptors[item.platform]?.displayName ??
            item.platform.name;
        rows.add(
          Padding(
            key: Key('templateSlotRow_${widget.id}_${slot.id}'),
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
    }

    // Omit an empty card for a visitor (the placeholder is an owner-only
    // call-to-action).
    if (rows.isEmpty && !showEmptyPlaceholder) return const SizedBox.shrink();

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
