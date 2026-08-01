import 'profile_archetype.dart';
import 'profile_layout.dart';
import 'profile_widget.dart';

/// Which side of a target card a paired half lands on.
enum DropSide { left, right }

/// The arrangement a profile reads in when its owner has never arranged one:
/// every widget as a full row, ordered by the question-category the add
/// catalog groups by, position breaking ties inside a category and the kinds
/// outside the category model trailing.
///
/// One function rather than one per surface, because the read view, the
/// visitor render and the editor's bootstrap must all show the same profile —
/// a second ordering written anywhere would silently disagree with this one.
///
/// A hidden widget gets a row here too. The read views drop it when they
/// resolve the row's card, so it stays hidden; the editor keeps the row, which
/// is the only place its owner can reach it to move or remove it. Filtering it
/// out here would strand it instead — present enough for the add catalog to
/// call it already added, absent everywhere it could be managed.
List<ProfileLayoutRow> defaultLayoutFor(
  List<ProfileWidget> widgets, {
  CardSizeSupport? supportsFull,
}) {
  final ordered = [...widgets]
    ..sort((a, b) {
      final categoryA =
          cardCategory(a.kind)?.index ?? ProfileCardCategory.values.length;
      final categoryB =
          cardCategory(b.kind)?.index ?? ProfileCardCategory.values.length;
      if (categoryA != categoryB) return categoryA - categoryB;
      return a.position.compareTo(b.position);
    });
  // A half-only archetype cannot seed as a full row; it starts as a
  // single-slot pair (a centered orphan) so its slot is legal from the start.
  // Defensive: no current archetype is half-only.
  return [
    for (final w in ordered)
      supportsFull == null || supportsFull(w.id)
          ? FullRow(w.id)
          : PairRow(left: w.id),
  ];
}

/// Answers whether the card behind [cardId] supports a given size. The controller
/// builds one of these per profile from the archetype registry so these pure
/// mutations never reach into the widget/archetype layer.
typedef CardSizeSupport = bool Function(String cardId);

/// A pair row with exactly one occupied slot — it renders as a centered orphan.
bool isOrphanRow(ProfileLayoutRow row) => switch (row) {
  FullRow() => false,
  // Exactly one of the two slots is filled.
  PairRow(:final left, :final right) => (left != null) != (right != null),
};

/// The non-null card ids in [row], in slot order.
List<String> _cardIds(ProfileLayoutRow row) => switch (row) {
  FullRow(:final cardId) => [cardId],
  PairRow(:final left, :final right) => [?left, ?right],
};

/// Drops ids absent from [knownIds] and collapses rows that become empty,
/// preserving order. Seeds the editor so a deleted-widget id can never reach the
/// save. Ids that are present but disabled are KEPT — a disabled card keeps its
/// slot until the owner moves it.
List<ProfileLayoutRow> normalizeLayout(
  List<ProfileLayoutRow> rows,
  Set<String> knownIds,
) {
  final out = <ProfileLayoutRow>[];
  for (final row in rows) {
    switch (row) {
      case FullRow(:final cardId):
        if (knownIds.contains(cardId)) out.add(row);
      case PairRow(:final left, :final right):
        final keptLeft = left != null && knownIds.contains(left) ? left : null;
        final keptRight = right != null && knownIds.contains(right)
            ? right
            : null;
        if (keptLeft == null && keptRight == null) continue;
        if (keptLeft == left && keptRight == right) {
          out.add(row);
        } else {
          out.add(PairRow(left: keptLeft, right: keptRight));
        }
    }
  }
  return out;
}

/// Whether [rows] still place [id] in some slot.
bool layoutHolds(List<ProfileLayoutRow> rows, String id) =>
    rows.any((row) => _cardIds(row).contains(id));

/// Whether [dragId] may drop beside [targetId] in the row at [rowIndex]: both
/// support half AND the row has room (full, orphan, or already holds [dragId]).
/// Full-only cards and already-full pairs return false, so the UI never offers
/// the side drop.
bool canPairBeside(
  List<ProfileLayoutRow> rows,
  int rowIndex,
  String dragId,
  String targetId, {
  required CardSizeSupport supportsHalf,
}) {
  if (targetId == dragId) return false;
  if (!supportsHalf(dragId) || !supportsHalf(targetId)) return false;
  final row = rows[rowIndex];
  return row is FullRow || isOrphanRow(row) || _cardIds(row).contains(dragId);
}

/// The card in the row at [rowIndex] that [dragId] would pair with, or null when
/// the row is no destination for it. At most one card ever qualifies: a pair row
/// already holding two other cards has no room for a third, so a row never has
/// to choose between two offers.
///
/// Expressed through [canPairBeside] rather than restating the rule, so the drop
/// a row offers is by construction the one the guard allows.
String? pairTargetAt(
  List<ProfileLayoutRow> rows,
  int rowIndex,
  String dragId, {
  required CardSizeSupport supportsHalf,
}) {
  for (final id in _cardIds(rows[rowIndex])) {
    if (canPairBeside(rows, rowIndex, dragId, id, supportsHalf: supportsHalf)) {
      return id;
    }
  }
  return null;
}

/// Where [id] currently sits, or null when it is not placed.
({int row, int slot})? _findCard(List<ProfileLayoutRow> rows, String id) {
  for (var i = 0; i < rows.length; i++) {
    switch (rows[i]) {
      case FullRow(:final cardId):
        if (cardId == id) return (row: i, slot: 0);
      case PairRow(:final left, :final right):
        if (left == id) return (row: i, slot: 0);
        if (right == id) return (row: i, slot: 1);
    }
  }
  return null;
}

/// Removes [id] from its current row. A full row is deleted; a pair slot is
/// nulled and the row deleted only if that empties it. [removedRow] is the index
/// of a deleted row, or -1 when the row survived (a pair kept its other card).
({List<ProfileLayoutRow> rows, int removedRow}) _removeCard(
  List<ProfileLayoutRow> rows,
  String id,
) {
  final out = [...rows];
  for (var i = 0; i < out.length; i++) {
    final row = out[i];
    switch (row) {
      case FullRow(:final cardId):
        if (cardId != id) continue;
        out.removeAt(i);
        return (rows: out, removedRow: i);
      case PairRow(:final left, :final right):
        if (left != id && right != id) continue;
        final keptLeft = left == id ? null : left;
        final keptRight = right == id ? null : right;
        if (keptLeft == null && keptRight == null) {
          out.removeAt(i);
          return (rows: out, removedRow: i);
        }
        out[i] = PairRow(left: keptLeft, right: keptRight);
        return (rows: out, removedRow: -1);
    }
  }
  return (rows: out, removedRow: -1);
}

/// Removes [id] from its row: a full row is deleted; a pair slot is nulled and
/// the row dropped only if that empties it. Order preserved. Pure; no-op if [id]
/// is absent.
List<ProfileLayoutRow> removeCard(List<ProfileLayoutRow> rows, String id) =>
    _removeCard(rows, id).rows;

/// Move [id] into the gap at [gapIndex] as its own row, **at the size it
/// already has**: a card in a full row lands full, a card in a pair slot lands
/// as a centered orphan. Moving is not resizing — [toggleSize] is the control
/// for that. Removes [id] from its current row first and shifts the target index
/// down by one when the removed row sat strictly before the gap.
///
/// A layout that no longer places [id] is returned untouched: a card that is not
/// placed has no size to preserve, and re-inserting it would resurrect a row for
/// a card deleted while it was in the air.
List<ProfileLayoutRow> moveToGap(
  List<ProfileLayoutRow> rows,
  String id,
  int gapIndex,
) {
  final from = _findCard(rows, id);
  if (from == null) return [...rows];
  final wasFull = rows[from.row] is FullRow;
  final removed = _removeCard(rows, id);
  var index = gapIndex;
  if (removed.removedRow > -1 && removed.removedRow < index) index--;
  final out = removed.rows;
  out.insert(index, wasFull ? FullRow(id) : PairRow(left: id));
  return out;
}

/// Pair [dragId] beside [targetId] on [side]; removes [dragId] from its current
/// row first, then rewrites the target's row to the ordered pair. A same-row drop
/// on the opposite side is the left/right swap.
List<ProfileLayoutRow> pairBeside(
  List<ProfileLayoutRow> rows,
  String dragId,
  String targetId,
  DropSide side,
) {
  final out = _removeCard(rows, dragId).rows;
  for (var i = 0; i < out.length; i++) {
    if (!_cardIds(out[i]).contains(targetId)) continue;
    out[i] = side == DropSide.left
        ? PairRow(left: dragId, right: targetId)
        : PairRow(left: targetId, right: dragId);
    return out;
  }
  return out;
}

/// The size toggle. Full → an in-place single-slot pair (orphan half). Half with
/// a partner → the partner becomes a centered orphan in place and [id] moves to a
/// new full row right after. Half with no partner → full in place.
List<ProfileLayoutRow> toggleSize(List<ProfileLayoutRow> rows, String id) {
  final pos = _findCard(rows, id);
  if (pos == null) return [...rows];
  final out = [...rows];
  switch (out[pos.row]) {
    case FullRow():
      out[pos.row] = PairRow(left: id);
    case PairRow(:final left, :final right):
      final partner = (left != null && left != id)
          ? left
          : (right != null && right != id ? right : null);
      if (partner != null) {
        out[pos.row] = PairRow(left: partner);
        out.insert(pos.row + 1, FullRow(id));
      } else {
        out[pos.row] = FullRow(id);
      }
  }
  return out;
}
