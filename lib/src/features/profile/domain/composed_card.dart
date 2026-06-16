import 'package:equatable/equatable.dart';

/// The owner's freely-picked item set for a composed-card widget: an ordered
/// list of data-menu item ids. Unlike a template, a composed card has no
/// predefined slots — the owner picks any items, and the pick order is the
/// render order. Catalog-free: it carries only the picked ids, resolved through
/// the data-menu catalog + [resolveSlot] at render.
final class ComposedFill extends Equatable {
  const ComposedFill(this.itemIds);

  /// Ordered data-menu item ids the owner picked, in pick order. Order is the
  /// render order; duplicates are not stored.
  final List<String> itemIds;

  static const empty = ComposedFill(<String>[]);

  bool get isEmpty => itemIds.isEmpty;
  bool contains(String id) => itemIds.contains(id);

  /// Adds [id] at the end when absent, removes it when present (free toggle).
  ComposedFill toggle(String id) => contains(id)
      ? ComposedFill([
          for (final e in itemIds)
            if (e != id) e,
        ])
      : ComposedFill([...itemIds, id]);

  @override
  List<Object?> get props => [itemIds];
}
