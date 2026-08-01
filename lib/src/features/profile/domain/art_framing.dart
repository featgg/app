import 'package:equatable/equatable.dart';

/// How a picture sits inside the frame that crops it: which point of it the
/// frame keeps, and how large it is drawn. `(0.5, 0.5)` is the picture's middle,
/// `(0, 0)` its top-left.
///
/// A point, not a rectangle, and that is the whole design. A rectangle belongs
/// to one frame shape: move a card from full to half and the saved rectangle
/// describes a region of a frame that no longer exists, so the choice has to be
/// made again. A point belongs to the picture, so it stays correct in every
/// frame the picture can land in — both card sizes, and any surface added
/// later.
///
/// The size follows the same rule: a multiple of what it takes to cover the
/// frame, never an absolute number of pixels. A multiple keeps the floor true
/// wherever the picture lands, because covering is defined against whatever
/// frame it is in; an absolute size would letterbox the moment the card changed
/// proportions.
final class ArtFraming extends Equatable {
  const ArtFraming({required this.x, required this.y, this.scale = coverScale});

  /// Clamps to the picture's own bounds and the frame's floor. A value outside
  /// them names no part of the picture, so it can only come from a corrupt
  /// envelope or one written by a build that meant something else by it.
  factory ArtFraming.clamped(double x, double y, {double scale = coverScale}) =>
      ArtFraming(
        x: x.clamp(0.0, 1.0),
        y: y.clamp(0.0, 1.0),
        // Guarded because this is the one field arithmetic on a live gesture
        // produces and the wire then has to carry: a non-finite value would
        // break the transform and produce a body the encoder cannot serialize.
        scale: scale.isFinite ? scale.clamp(coverScale, maxScale) : coverScale,
      );

  /// The size at which the picture exactly covers its frame. The floor: below
  /// it the frame would show ground the picture does not reach.
  static const double coverScale = 1;

  /// How far past covering the picture may be drawn. A ceiling exists because
  /// past it a card is showing a handful of source pixels stretched over its
  /// whole width.
  static const double maxScale = 3;

  /// 0 at the picture's left edge, 1 at its right.
  final double x;

  /// 0 at the picture's top edge, 1 at its bottom.
  final double y;

  /// A multiple of the size that covers the frame, never an absolute size.
  final double scale;

  /// What every surface shows until the owner moves it, and what the renderer
  /// has always done: the middle of the picture survives the crop, at the size
  /// that covers the frame.
  static const center = ArtFraming(x: 0.5, y: 0.5);

  /// Nothing the owner chose.
  bool get isDefault => this == center;

  /// Moves the point by a fraction of the picture, keeping it inside bounds and
  /// keeping the size it is drawn at.
  ArtFraming shifted({required double dx, required double dy}) =>
      ArtFraming.clamped(x + dx, y + dy, scale: scale);

  /// Redraws the picture at [scale], anchored on the same point.
  ArtFraming scaledTo(double scale) => ArtFraming.clamped(x, y, scale: scale);

  @override
  List<Object?> get props => [x, y, scale];
}
