import 'package:equatable/equatable.dart';

import '../../connections/domain/game_card.dart';
import 'data_menu_catalog.dart';

/// A resolved slot ready to render: the catalog item (carrying its label key and
/// value type) plus the raw value and unit token read from the card.
final class ResolvedSlotValue extends Equatable {
  const ResolvedSlotValue({required this.item, required this.value, this.unit});

  /// Carries [DataMenuItem.labelKey] + [DataMenuItem.valueType] for formatting.
  final DataMenuItem item;

  /// Raw stat value (number/string/bool) for an envelope stat, or a
  /// pre-formatted string for a composed data-block value.
  final Object value;

  /// Stable unit token, or null.
  final String? unit;

  @override
  List<Object?> get props => [item, value, unit];
}

/// Resolves a filled slot to its value, or null when it cannot be shown
/// (soft-omit). Returns null when:
///
/// - [itemId] is null or not a catalog item id,
/// - [card] is null (platform unlinked / no card row),
/// - an envelope [StatPointer] (`dataPath == null`) has no matching
///   [GameCard.stats] entry,
/// - a data-block [StatPointer] (`dataPath != null`) field is absent / the card
///   carries a different data block (see [_resolveDataBlock]),
/// - the pointer is a [ShowcasePointer] (non-scalar list; not resolved in v1).
///
/// Pure: reads only [GameCard] fields; imports only connections `domain`.
ResolvedSlotValue? resolveSlot(String? itemId, GameCard? card) {
  if (itemId == null || card == null) return null;
  final item = _itemById(itemId);
  if (item == null) return null;

  return switch (item.pointer) {
    StatPointer(:final statKey, dataPath: null) => _resolveStat(
      item,
      card,
      statKey,
    ),
    StatPointer() => _resolveDataBlock(item, card),
    ShowcasePointer() => null,
  };
}

DataMenuItem? _itemById(String id) {
  for (final item in dataMenuCatalog) {
    if (item.id == id) return item;
  }
  return null;
}

/// Generic envelope path: reads [GameCard.stats] by [statKey]. Covers every
/// catalog item whose value lives in the frozen `stats[]` envelope, with no
/// per-platform code. Absent key → null (soft-omit).
ResolvedSlotValue? _resolveStat(
  DataMenuItem item,
  GameCard card,
  String statKey,
) {
  for (final stat in card.stats) {
    if (stat.key == statKey) {
      return ResolvedSlotValue(item: item, value: stat.value, unit: stat.unit);
    }
  }
  return null;
}

/// Extracts a scalar value from the card's typed data block for a data-block
/// pointer ([StatPointer.dataPath] != null). One switch on the concrete
/// [CardData] type; one case per data-block field a catalog item needs. v1 needs
/// only LoL rank. Adding another data-block field is ONE new case here — no
/// change to the generic envelope path or to [resolveSlot]. Unhandled field /
/// absent block → null (soft-omit).
ResolvedSlotValue? _resolveDataBlock(DataMenuItem item, GameCard card) {
  final data = card.data;
  return switch (data) {
    LeagueOfLegendsCardData(:final rank)
        when item.id == 'league_of_legends.rank' =>
      rank == null
          ? null
          : ResolvedSlotValue(item: item, value: formatLolRank(rank)),
    WowRetailCardData(:final profile) when item.id == 'wow_retail.profile' =>
      ResolvedSlotValue(item: item, value: formatWowClassRace(profile)),
    _ => null,
  };
}

/// Formats a LoL ranked standing as a single line: tier + division + LP, e.g.
/// 'GOLD II · 47 LP'. Pure and reusable by any future data-block rank pointer;
/// not per-item code. tier and division are raw contract tokens (the same tokens
/// the connections card view renders verbatim); LP is a number with a stable
/// 'LP' suffix token, not user-facing prose.
String formatLolRank(LolRank rank) =>
    '${rank.tier} ${rank.division} · ${rank.lp} LP';

/// Composes a WoW character's class and race as one line, e.g. 'Mage · Orc'.
/// className and race are raw contract tokens (the same tokens the connections
/// card view renders verbatim); never localized here.
String formatWowClassRace(WowProfile profile) =>
    '${profile.className} · ${profile.race}';
