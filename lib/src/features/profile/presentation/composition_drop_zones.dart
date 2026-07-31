import 'dart:math' as math;
import 'dart:ui';

import 'package:equatable/equatable.dart';

import '../../../core/core.dart';
import '../domain/profile_composition.dart';

/// A place a dragged card can land, and where it sits on screen.
///
/// Rectangles are in the rows region's own coordinates, so the page scrolling
/// under the finger never moves a zone.
sealed class DropZone extends Equatable {
  const DropZone({required this.rect});

  final Rect rect;
}

/// The insertion line between two rows: the card becomes its own row there.
final class GapZone extends DropZone {
  const GapZone({required this.index, required super.rect});

  final int index;

  @override
  List<Object?> get props => [index, rect];
}

/// A row the dragged card may pair with. The rectangle spans the whole column
/// across the row's height, which is what makes the empty half of an orphan row
/// a destination as readily as the card itself.
final class PairZone extends DropZone {
  const PairZone({
    required this.targetId,
    required this.cardCenterX,
    required super.rect,
  });

  final String targetId;

  /// The target card's own horizontal centre. The side is read against the
  /// card, not against the band, so a point in an orphan's empty half answers
  /// the side of the card it is actually on.
  final double cardCenterX;

  DropSide sideFor(Offset point) =>
      point.dx < cardCenterX ? DropSide.left : DropSide.right;

  @override
  List<Object?> get props => [targetId, cardCenterX, rect];
}

/// Straight-line distance from [point] to [rect]; zero anywhere inside it.
double _distanceTo(Rect rect, Offset point) {
  final dx = math.max(
    0.0,
    math.max(rect.left - point.dx, point.dx - rect.right),
  );
  final dy = math.max(
    0.0,
    math.max(rect.top - point.dy, point.dy - rect.bottom),
  );
  return math.sqrt(dx * dx + dy * dy);
}

/// Which of [zones] a drag at [point] holds, or null when it holds nothing.
///
/// The zones tile the region: gaps and pairable rows are measured edge to edge
/// down the column, and a row the card cannot pair with contributes no zone at
/// all — which is what makes a release over it fall to the nearest gap instead
/// of reading as dead. Inside [bounds] the nearest zone always wins however far
/// it is, so every point belongs to some landing place and [radius] governs
/// only the margin outside.
///
/// [current] is what the drag already holds; it keeps it while a rival is
/// nearer by no more than [hysteresis].
DropZone? resolveDropZone({
  required Offset point,
  required Rect bounds,
  required List<DropZone> zones,
  DropZone? current,
  double radius = PersonalizationLayout.dropAcquireRadius,
  double hysteresis = PersonalizationLayout.dropHysteresis,
}) {
  // Before the deadband, on purpose: a deadband smooths a boundary, it must
  // never keep a release the owner aimed out of the editor.
  if (!bounds.inflate(radius).contains(point)) return null;
  if (zones.isEmpty) return null;

  var best = zones.first;
  var bestScore = _distanceTo(best.rect, point);
  for (final zone in zones.skip(1)) {
    final score = _distanceTo(zone.rect, point);
    // Strictly nearer, so a tie goes to the earlier zone and the choice is
    // deterministic.
    if (score < bestScore) {
      best = zone;
      bestScore = score;
    }
  }

  if (current != null && zones.contains(current)) {
    if (_distanceTo(current.rect, point) - bestScore <= hysteresis) {
      return current;
    }
  }
  return best;
}
