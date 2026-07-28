import 'package:flutter/material.dart';

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
/// tablet, three centered on desktop.
int columnsFor(WindowSizeClass c) => switch (c) {
  WindowSizeClass.compact => 1,
  WindowSizeClass.medium => 2,
  WindowSizeClass.expanded => 3,
};

/// Cells the widget spans in a [columns]-column grid. Content-rich cards fill
/// the row (never a narrow cell); showcase/collection/game-collector/
/// completionist map small→1, wide→2, large→2 (the card's aspect ratio makes
/// large the tall footprint). Clamped to [columns].
int spanFor(ProfileWidget w, {required int columns}) {
  final sized =
      w.kind == ProfileWidgetKind.showcase ||
      w.kind == ProfileWidgetKind.collection ||
      w.kind == ProfileWidgetKind.gameCollector ||
      w.kind == ProfileWidgetKind.completionist ||
      w.kind == ProfileWidgetKind.passport;
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

/// Splits already-packed [tiles] into rows for the [columns]-column grid,
/// greedily filling each row up to [columns] cells (mirrors packForLayout's own
/// fill, so the rows are exactly what packing intended). Pure/deterministic.
List<List<ProfileWidgetTile>> groupRows(
  List<ProfileWidgetTile> tiles,
  int columns,
) {
  final rows = <List<ProfileWidgetTile>>[];
  var current = <ProfileWidgetTile>[];
  var remaining = columns;
  for (final t in tiles) {
    final s = spanFor(t.widget, columns: columns);
    if (s > remaining && current.isNotEmpty) {
      rows.add(current);
      current = <ProfileWidgetTile>[];
      remaining = columns;
    }
    current.add(t);
    remaining -= s;
    if (remaining <= 0) {
      rows.add(current);
      current = <ProfileWidgetTile>[];
      remaining = columns;
    }
  }
  if (current.isNotEmpty) rows.add(current);
  return rows;
}

/// Single full-width column on compact; an explicit multi-column row layout
/// (content-height tiles packed by [packForLayout], then grouped into rows by
/// [groupRows]) above the medium breakpoint, centered within
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
        final rows = groupRows(packForLayout(tiles, columns), columns);

        // Measure the real content width (≤ maxContentWidth on expanded, so the
        // width-measuring LayoutBuilder sits inside that constraint) to size each
        // cell exactly; a span-s tile absorbs the inter-cell gaps it spans.
        final grid = LayoutBuilder(
          builder: (context, inner) {
            final contentWidth = inner.maxWidth;
            final cellWidth =
                (contentWidth - AppSpacing.sm * (columns - 1)) / columns;
            double tileWidth(int span) =>
                span * cellWidth + (span - 1) * AppSpacing.sm;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.sm),
                  _row(rows[i], columns, tileWidth),
                ],
              ],
            );
          },
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

/// One grid row. A full row (its spans sum to [columns]) sizes tiles with
/// [Expanded] so cells distribute exactly and can never overflow; an under-full
/// row uses explicit widths from [tileWidth] — a lone orphan is centered, while
/// multiple tiles left-align with the empty cell(s) trailing. Tiles top-align so
/// unequal heights do not stretch.
Widget _row(
  List<ProfileWidgetTile> row,
  int columns,
  double Function(int span) tileWidth,
) {
  final rowSpan = row.fold<int>(
    0,
    (sum, t) => sum + spanFor(t.widget, columns: columns),
  );

  if (rowSpan == columns) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < row.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: spanFor(row[i].widget, columns: columns),
            child: row[i].child,
          ),
        ],
      ],
    );
  }

  final isOrphan = row.length == 1;
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: isOrphan
        ? MainAxisAlignment.center
        : MainAxisAlignment.start,
    children: [
      for (var i = 0; i < row.length; i++) ...[
        if (i > 0) const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: tileWidth(spanFor(row[i].widget, columns: columns)),
          child: row[i].child,
        ),
      ],
    ],
  );
}
