import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../domain/art_framing.dart';

/// Whose framing an art surface renders, so the surface can both apply it and,
/// where the owner is editing, hand a new one back.
class ArtFramingTarget {
  const ArtFramingTarget({required this.widgetId, required this.framing});

  final String widgetId;
  final ArtFraming framing;
}

/// Marks the subtree the owner is editing: the call that records a reframe,
/// and which single card is in framing mode.
///
/// Recording, not writing: a reframe is an edit like any other in the session,
/// so it waits for Done and is dropped by Cancel. Moving the art and being told
/// there is nothing to save is the session disagreeing with what the owner just
/// did.
///
/// The mode lives here rather than in each card because it is exclusive: one
/// card frames at a time, so the editor owns whose turn it is, the way it owns
/// which card is being dragged.
class ArtFramingScope extends InheritedWidget {
  const ArtFramingScope({
    super.key,
    required this.onChanged,
    required this.activeId,
    required this.onActivate,
    required super.child,
  });

  final void Function(String widgetId, ArtFraming framing) onChanged;

  /// The widget whose picture is being framed right now, or null.
  final String? activeId;

  /// Puts [activeId]'s card into framing mode; null leaves it.
  final void Function(String? widgetId) onActivate;

  static ArtFramingScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ArtFramingScope>();

  @override
  bool updateShouldNotify(ArtFramingScope oldWidget) =>
      onChanged != oldWidget.onChanged ||
      activeId != oldWidget.activeId ||
      onActivate != oldWidget.onActivate;
}

/// The point as the alignment the picture is painted at.
///
/// The crop and the scale both read this, and they must read the same one: the
/// picture is enlarged about the very point the crop is anchored on, which is
/// what keeps a zoom from sliding the picture out from under the choice the
/// owner already made.
Alignment artFramingAlignment(ArtFraming framing) =>
    Alignment(framing.x * 2 - 1, framing.y * 2 - 1);

/// How much of [image] a frame of [frame] cannot show, per axis, once the
/// picture is scaled to cover it and then enlarged by [scale]. Zero on an axis
/// means the picture ends where the frame does and there is nothing on that
/// axis to move to.
@visibleForTesting
Size artOverflow({
  required Size frame,
  required Size image,
  double scale = ArtFraming.coverScale,
}) {
  if (frame.isEmpty || image.isEmpty) return Size.zero;
  final drawn =
      math.max(frame.width / image.width, frame.height / image.height) * scale;
  return Size(
    math.max(0, image.width * drawn - frame.width),
    math.max(0, image.height * drawn - frame.height),
  );
}

/// The part of [image] a frame of [frame] shows at [framing], in the picture's
/// own coordinates (0..1 on each axis). Empty frame or image → [Rect.zero].
///
/// The executable statement of the one invariant the whole control rests on: at
/// any legal framing this rect lies inside the unit square, so the frame is
/// never showing anything that is not the picture. The render cannot state it —
/// it deliberately never learns the picture's pixel size, which is why it leans
/// on [BoxFit.cover] — so this models what the widget tree paints, and the
/// composition of that tree is asserted separately to keep the two from
/// drifting apart.
@visibleForTesting
Rect artVisibleRect({
  required Size frame,
  required Size image,
  required ArtFraming framing,
}) {
  if (frame.isEmpty || image.isEmpty) return Rect.zero;
  final drawn =
      math.max(frame.width / image.width, frame.height / image.height) *
      framing.scale;
  final painted = Size(image.width * drawn, image.height * drawn);
  final overflow = artOverflow(
    frame: frame,
    image: image,
    scale: framing.scale,
  );
  return Rect.fromLTWH(
    overflow.width * framing.x / painted.width,
    overflow.height * framing.y / painted.height,
    frame.width / painted.width,
    frame.height / painted.height,
  );
}

/// An explicit framing mode, entered from the mark on the card.
///
/// Tap the mark; the card enters framing; an ordinary one-finger drag moves the
/// picture, both axes, and a pinch draws it larger; tap the mark again — or
/// anywhere outside the card — to leave. Inside the mode the card owns the
/// gesture outright, so there is no contest with the page; outside it the
/// picture is inert and the page scrolls exactly as it always did. Ownership,
/// not delay: this replaced a hold that existed only to survive the scroll
/// contest, and that nothing else in the industry uses for framing.
///
/// Offered only where it does something. A card earns the mark by carrying a
/// picture that loaded — any picture can be drawn larger inside its frame, even
/// one the frame crops none of. A picture that failed to load, and a card with
/// no picture at all, have nothing to reveal, and a control that answers with
/// no movement reads as broken.
class ArtFramingGesture extends StatefulWidget {
  const ArtFramingGesture({
    super.key,
    required this.imageUrl,
    required this.framing,
    required this.active,
    required this.onActiveChanged,
    required this.onChanged,
    required this.builder,
  });

  final String imageUrl;
  final ArtFraming framing;

  /// Whether this card is the one in framing mode.
  final bool active;

  /// Asks the editor to put this card in or out of the mode.
  final ValueChanged<bool> onActiveChanged;

  /// Records where a gesture left the picture, and at what size.
  final ValueChanged<ArtFraming> onChanged;

  /// Builds the art at the framing to paint — the in-flight one while the owner
  /// is moving it, the recorded one otherwise.
  final Widget Function(BuildContext context, ArtFraming framing) builder;

  @override
  State<ArtFramingGesture> createState() => _ArtFramingGestureState();
}

/// How much larger one press of a zoom mark draws the picture. Coarse enough
/// that a few presses cross the whole range, fine enough that no press jumps
/// past the framing the owner was aiming at.
const double _scaleStep = 0.25;

class _ArtFramingGestureState extends State<ArtFramingGesture> {
  /// The picture's own dimensions, or null until it has loaded — and forever if
  /// it never does.
  Size? _image;

  ImageStream? _stream;
  ImageStreamListener? _listener;

  /// The framing the finger is on. Held past the release so the picture does
  /// not step back while the session records it.
  ArtFraming? _live;

  /// The size the picture was drawn at when the gesture began. Every update
  /// reads it rather than the last one, so a pinch past the ceiling and back
  /// recovers exactly instead of drifting.
  double? _startScale;

  Size _frame = Size.zero;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(ArtFramingGesture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _image = null;
      _resolve();
    }
    // What the session holds outranks the local preview.
    if (oldWidget.framing != widget.framing) _live = null;
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _detach() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  void _resolve() {
    _detach();
    final stream = CachedNetworkImageProvider(
      widget.imageUrl,
    ).resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (info, _) {
        final image = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
        if (mounted) setState(() => _image = image);
      },
      // A picture that never arrives simply never earns the control.
      onError: (_, _) {},
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  Size _overflowAt(double scale) {
    final image = _image;
    if (image == null) return Size.zero;
    return artOverflow(frame: _frame, image: image, scale: scale);
  }

  /// Whether there is a picture to frame at all. Any picture that loaded can be
  /// drawn larger inside its frame, so the crop is no longer what earns the
  /// control.
  bool get _framable => !(_image?.isEmpty ?? true);

  void _onScaleStart(ScaleStartDetails details) {
    _startScale = (_live ?? widget.framing).scale;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final from = _live ?? widget.framing;
    final scaled = from.scaledTo((_startScale ?? from.scale) * details.scale);
    // Against the overflow at the size being drawn now, so a pixel of finger
    // stays a pixel of picture however large it is.
    final overflow = _overflowAt(scaled.scale);
    final delta = details.focalPointDelta;
    setState(() {
      // The picture tracks the finger: a pixel of drag is a pixel of picture.
      // Dragging right pulls the picture right, which brings the part to its
      // left into view — so the point being looked at moves the other way.
      _live = scaled.shifted(
        dx: overflow.width == 0 ? 0 : -delta.dx / overflow.width,
        dy: overflow.height == 0 ? 0 : -delta.dy / overflow.height,
      );
    });
  }

  /// Draws the picture [by] larger or smaller, for the owner who has no pinch.
  /// A press is its own beginning and end, so it records straight away.
  void _step(double by) {
    final from = _live ?? widget.framing;
    final next = from.scaledTo(from.scale + by);
    if (next == from) return;
    setState(() => _live = next);
    widget.onChanged(next);
  }

  void _release() {
    final settled = _live;
    if (settled != null && settled != widget.framing) {
      widget.onChanged(settled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = PersonalizationTheme.of(context);
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        _frame = constraints.biggest;
        final framing = _live ?? widget.framing;
        final art = widget.builder(context, framing);
        if (!_framable) return art;
        if (!widget.active) {
          // Inert but for the mark: the page keeps every gesture, so scrolling
          // over the card works exactly as it does over any other.
          return Stack(
            fit: StackFit.expand,
            children: [
              art,
              Align(
                child: ArtFramingBadge(
                  icon: Icons.open_with,
                  label: l10n.profileArtFramingStart,
                  onTap: () => widget.onActiveChanged(true),
                ),
              ),
            ],
          );
        }
        // A press anywhere outside the card — including the one that starts a
        // scroll — puts the mode down. Leaving is never the owner's problem.
        return TapRegion(
          onTapOutside: (_) => widget.onActiveChanged(false),
          child: Semantics(
            label: l10n.profileArtFramingLabel,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // One recognizer for both: uncontested, because the mode
                  // holds the page still, so there is nothing left to out-wait.
                  // A single finger reports a scale of 1 and a live focal
                  // delta, which is the drag; two fingers scale as they move.
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: _onScaleUpdate,
                  onScaleEnd: (_) => _release(),
                  child: art,
                ),
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: palette.accent,
                        width: PersonalizationLayout.borderWidth,
                      ),
                    ),
                  ),
                ),
                // The free edge: the corners belong to the handle, the delete,
                // the size toggle and the card's number, and the confirm holds
                // the top. Enlarge over reduce is the convention every map and
                // viewer uses, and it needs no branch on the kind of input.
                Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ArtFramingBadge(
                        icon: Icons.zoom_in,
                        label: l10n.profileArtFramingZoomIn,
                        enabled: framing.scale < ArtFraming.maxScale,
                        onTap: () => _step(_scaleStep),
                      ),
                      ArtFramingBadge(
                        icon: Icons.zoom_out,
                        label: l10n.profileArtFramingZoomOut,
                        enabled: framing.scale > ArtFraming.coverScale,
                        onTap: () => _step(-_scaleStep),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: ArtFramingBadge(
                    icon: Icons.check,
                    filled: true,
                    label: l10n.profileArtFramingDone,
                    onTap: () => widget.onActiveChanged(false),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One mark of the framing mode: the square button that enters it, the one that
/// confirms and leaves it, and the pair that draws the picture larger or
/// smaller. One shape for all of them, so the mode reads as one control.
///
/// It places nothing: where a mark sits is the caller's decision, because the
/// spots are chosen against each other. The idle mark is centred, because every
/// corner of a card in the editor is already spoken for — the handle, the
/// delete, the size toggle, and the card's own number in the fourth — and the
/// middle is where a finger lands on a picture. Once the mode is on, that same
/// spot is where the drag begins, so the confirm steps aside to the top edge
/// instead of sitting on the gesture it would otherwise swallow, and the zoom
/// pair takes the free right edge.
///
/// [filled] is the inverted paint the confirm takes. [enabled] false paints the
/// glyph muted and drops the press, for a step that has nowhere left to go.
///
/// It sits above the drag layer on its own pixels only, so a drag starting
/// anywhere else on the picture never has to compete with it.
class ArtFramingBadge extends StatelessWidget {
  const ArtFramingBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = PersonalizationTheme.of(context);
    return Semantics(
      label: label,
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.xs),
          width: AppSpacing.xl,
          height: AppSpacing.xl,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? palette.accent : palette.bg,
            border: Border.all(
              color: palette.accent,
              width: PersonalizationLayout.borderWidth,
            ),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Icon(
            icon,
            size: AppSpacing.md,
            color: switch ((enabled, filled)) {
              (false, _) => palette.muted,
              (true, true) => palette.bg,
              (true, false) => palette.text,
            },
          ),
        ),
      ),
    );
  }
}
