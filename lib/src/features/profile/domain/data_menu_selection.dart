import 'package:equatable/equatable.dart';

/// The owner's per-widget choice of which catalog items the card surfaces, as a
/// set of [DataMenuItem.id] tokens. An empty selection means "default": the
/// widget behaves exactly as before this slice, so an un-customized widget is
/// unaffected.
final class DataMenuSelection extends Equatable {
  const DataMenuSelection(this.selectedIds);

  /// Catalog item ids the owner has turned on for this widget.
  final Set<String> selectedIds;

  static const empty = DataMenuSelection(<String>{});

  /// True when nothing is selected — the card uses its default behavior.
  bool get isDefault => selectedIds.isEmpty;

  bool contains(String id) => selectedIds.contains(id);

  /// Returns a selection with [id] added when absent, removed when present.
  DataMenuSelection toggle(String id) {
    final next = {...selectedIds};
    if (!next.add(id)) next.remove(id);
    return DataMenuSelection(next);
  }

  @override
  List<Object?> get props => [selectedIds];
}
