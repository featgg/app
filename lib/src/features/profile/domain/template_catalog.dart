import 'package:equatable/equatable.dart';

import 'data_menu_catalog.dart';

/// One named slot in a template. Accepts data-menu items of exactly one
/// [DataMenuCategory]; the owner fills it by picking a [DataMenuItem] of that
/// category. [labelKey] names an l10n key resolved in presentation.
final class TemplateSlot extends Equatable {
  const TemplateSlot({
    required this.id,
    required this.category,
    required this.labelKey,
  });

  /// Stable token, unique within its template.
  final String id;
  final DataMenuCategory category;
  final String labelKey;

  @override
  List<Object?> get props => [id, category, labelKey];
}

/// One template = a localized title + up to a few named slots. Adding a
/// template is appending ONE const entry to [templateCatalog]; adding a slot is
/// one [TemplateSlot] in its `slots` list. No other code changes.
final class TemplateDefinition extends Equatable {
  const TemplateDefinition({
    required this.id,
    required this.titleKey,
    required this.slots,
  });

  /// Stable token persisted in `settings`.
  final String id;
  final String titleKey;
  final List<TemplateSlot> slots;

  @override
  List<Object?> get props => [id, titleKey, slots];
}

/// The v1 template catalog. Each slot's category is a [DataMenuCategory] from
/// the data menu, so a slot is filled by picking a data-menu item of that
/// category. Adding a template = appending ONE const entry; the iterating tests
/// need no new case for a conformant addition.
const List<TemplateDefinition> templateCatalog = [
  TemplateDefinition(
    id: 'my_ranks',
    titleKey: 'templateMyRanksTitle',
    slots: [
      TemplateSlot(
        id: 'slot_1',
        category: DataMenuCategory.ranksCompetitive,
        labelKey: 'templateSlotRank1',
      ),
      TemplateSlot(
        id: 'slot_2',
        category: DataMenuCategory.ranksCompetitive,
        labelKey: 'templateSlotRank2',
      ),
      TemplateSlot(
        id: 'slot_3',
        category: DataMenuCategory.ranksCompetitive,
        labelKey: 'templateSlotRank3',
      ),
    ],
  ),
  TemplateDefinition(
    id: 'my_achievements',
    titleKey: 'templateMyAchievementsTitle',
    slots: [
      TemplateSlot(
        id: 'slot_1',
        category: DataMenuCategory.achievements,
        labelKey: 'templateSlotAchievement1',
      ),
      TemplateSlot(
        id: 'slot_2',
        category: DataMenuCategory.achievements,
        labelKey: 'templateSlotAchievement2',
      ),
      TemplateSlot(
        id: 'slot_3',
        category: DataMenuCategory.achievements,
        labelKey: 'templateSlotAchievement3',
      ),
    ],
  ),
  TemplateDefinition(
    id: 'my_levels',
    titleKey: 'templateMyLevelsTitle',
    slots: [
      TemplateSlot(
        id: 'slot_1',
        category: DataMenuCategory.levelsIdentity,
        labelKey: 'templateSlotLevel1',
      ),
      TemplateSlot(
        id: 'slot_2',
        category: DataMenuCategory.levelsIdentity,
        labelKey: 'templateSlotLevel2',
      ),
      TemplateSlot(
        id: 'slot_3',
        category: DataMenuCategory.levelsIdentity,
        labelKey: 'templateSlotLevel3',
      ),
    ],
  ),
];

/// Returns the [TemplateDefinition] with [id], or null when no definition
/// matches (a stale/unknown token soft-resolves to null at the call site).
TemplateDefinition? templateDefinitionById(String? id) {
  if (id == null) return null;
  for (final definition in templateCatalog) {
    if (definition.id == id) return definition;
  }
  return null;
}

/// The owner's fills for a template widget: a map slot-id → DataMenuItem.id.
/// An absent slot id means "empty" (soft-omitted on render). Reuses the data
/// menu catalog item id as the data-menu pointer — no new pointer type.
final class TemplateFill extends Equatable {
  const TemplateFill(this.templateId, this.slotItemIds);

  /// Null until a template is chosen.
  final String? templateId;

  /// slotId -> dataMenuItem.id.
  final Map<String, String> slotItemIds;

  static const empty = TemplateFill(null, <String, String>{});

  bool get isEmpty => templateId == null;

  /// The data-menu item id filled into [slotId], or null when empty.
  String? itemIdFor(String slotId) => slotItemIds[slotId];

  /// Sets or replaces the fill for [slotId].
  TemplateFill withSlot(String slotId, String itemId) =>
      TemplateFill(templateId, {...slotItemIds, slotId: itemId});

  /// Removes the fill for [slotId].
  TemplateFill clearedSlot(String slotId) => TemplateFill(templateId, {
    for (final entry in slotItemIds.entries)
      if (entry.key != slotId) entry.key: entry.value,
  });

  @override
  List<Object?> get props => [templateId, slotItemIds];
}
