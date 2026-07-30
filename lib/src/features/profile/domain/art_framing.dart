import 'package:equatable/equatable.dart';

/// Where in a picture the part that matters is, as a fraction of the picture's
/// own width and height. `(0.5, 0.5)` is its middle, `(0, 0)` its top-left.
///
/// A point, not a rectangle, and that is the whole design. A rectangle belongs
/// to one frame shape: move a card from full to half and the saved rectangle
/// describes a region of a frame that no longer exists, so the choice has to be
/// made again. A point belongs to the picture, so it stays correct in every
/// frame the picture can land in — both card sizes, and any surface added
/// later.
final class ArtFraming extends Equatable {
  const ArtFraming({required this.x, required this.y});

  /// Clamps to the picture's own bounds. A value outside them names no part of
  /// the picture, so it can only come from a corrupt envelope or one written by
  /// a build that meant something else by it.
  factory ArtFraming.clamped(double x, double y) =>
      ArtFraming(x: x.clamp(0.0, 1.0), y: y.clamp(0.0, 1.0));

  /// 0 at the picture's left edge, 1 at its right.
  final double x;

  /// 0 at the picture's top edge, 1 at its bottom.
  final double y;

  /// What every surface shows until the owner moves it, and what the renderer
  /// has always done: the middle of the picture survives the crop.
  static const center = ArtFraming(x: 0.5, y: 0.5);

  bool get isCenter => this == center;

  /// Moves the point by a fraction of the picture, keeping it inside bounds.
  ArtFraming shifted({required double dx, required double dy}) =>
      ArtFraming.clamped(x + dx, y + dy);

  @override
  List<Object?> get props => [x, y];
}
