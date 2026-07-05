import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../core/core.dart';
import '../domain/profile_widget.dart';

/// A position-ordered widget plus its prebuilt tile. The flow reads the span
/// from [widget]; the caller owns how [child] renders (owner tile with menu, or
/// read-only visitor tile).
class ProfileWidgetTile {
  const ProfileWidgetTile({required this.widget, required this.child});

  final ProfileWidget widget;
  final Widget child;
}

/// Columns in a [WindowSizeClass]'s grid: single column on phone, two on
/// tablet, three centered on desktop (design-system §9 / §13).
int columnsFor(WindowSizeClass c) => switch (c) {
  WindowSizeClass.compact => 1,
  WindowSizeClass.medium => 2,
  WindowSizeClass.expanded => 3,
};

/// Cells the widget spans in a [columns]-column grid. Content-rich cards fill
/// the row (never a narrow cell); showcase/collection map small→1, wide→2,
/// large→2 (the card's aspect ratio makes large the tall footprint). Clamped to
/// [columns].
int spanFor(ProfileWidget w, {required int columns}) {
  final sized =
      w.kind == ProfileWidgetKind.showcase ||
      w.kind == ProfileWidgetKind.collection;
  if (!sized) return columns;
  final cells = switch (w.size) {
    ProfileWidgetSize.small => 1,
    ProfileWidgetSize.wide => 2,
    ProfileWidgetSize.large => 2,
  };
  return cells > columns ? columns : cells;
}

/// Reorders [tiles] FOR LAYOUT ONLY so the [columns]-column grid does not
/// strand cells, while moving each tile as little as possible: it walks the
/// tiles in position order and, whenever the leftover cells of the current row
/// cannot hold the next tile, pulls the NEAREST following tile that fits into
/// the gap (never an arbitrary/farther one). If nothing fits the leftover, the
/// row is closed and the unavoidable gap remains. Persisted order (`position`)
/// is not touched; this only affects render packing. Deterministic and stable.
List<ProfileWidgetTile> packForLayout(
  List<ProfileWidgetTile> tiles,
  int columns,
) {
  final queue = [...tiles];
  final packed = <ProfileWidgetTile>[];
  var remaining = columns;
  while (queue.isNotEmpty) {
    var idx = queue.indexWhere(
      (t) => spanFor(t.widget, columns: columns) <= remaining,
    );
    if (idx == -1) {
      // Nothing fits the leftover cells → close the row; the first tile starts
      // a fresh row (its span is clamped to <= columns, so it always fits).
      remaining = columns;
      idx = 0;
    }
    final tile = queue.removeAt(idx);
    packed.add(tile);
    remaining -= spanFor(tile.widget, columns: columns);
    if (remaining <= 0) remaining = columns;
  }
  return packed;
}

/// Single full-width column on compact; an auto-packing multi-column staggered
/// grid (content-height tiles) above the medium breakpoint, centered within
/// [AppBreakpoints.maxContentWidth] on expanded. Non-scrolling — it embeds in
/// the profile screen's own scroll view, which gives it a bounded width for its
/// own [LayoutBuilder].
class ProfileWidgetsFlow extends StatelessWidget {
  const ProfileWidgetsFlow({super.key, required this.tiles});

  final List<ProfileWidgetTile> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sizeClass = windowSizeClassForWidth(constraints.maxWidth);

        if (sizeClass == WindowSizeClass.compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                tiles[i].child,
              ],
            ],
          );
        }

        final columns = columnsFor(sizeClass);
        final laidOut = packForLayout(tiles, columns);
        final grid = StaggeredGrid.count(
          crossAxisCount: columns,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          children: [
            for (final tile in laidOut)
              StaggeredGridTile.fit(
                crossAxisCellCount: spanFor(tile.widget, columns: columns),
                child: tile.child,
              ),
          ],
        );

        if (sizeClass == WindowSizeClass.expanded) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppBreakpoints.maxContentWidth,
              ),
              child: grid,
            ),
          );
        }
        return grid;
      },
    );
  }
}
