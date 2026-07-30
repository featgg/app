import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
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

/// Marks the subtree the owner is editing, and carries the call that records a
/// reframe.
///
/// Recording, not writing: a reframe is an edit like any other in the session,
/// so it waits for Done and is dropped by Cancel. Moving the art and being told
/// there is nothing to save is the session disagreeing with what the owner just
/// did.
///
/// An inherited marker rather than a parameter threaded through every card: the
/// read view and the editor build cards from the same builder, and only the
/// enclosing surface knows which of the two it is.
class ArtFramingScope extends InheritedWidget {
  const ArtFramingScope({
    super.key,
    required this.onChanged,
    required super.child,
  });

  final void Function(String widgetId, ArtFraming framing) onChanged;

  static ArtFramingScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ArtFramingScope>();

  @override
  bool updateShouldNotify(ArtFramingScope oldWidget) =>
      onChanged != oldWidget.onChanged;
}

/// How much of [image] a frame of [frame] cannot show, per axis, once the
/// picture is scaled to cover it. Zero on an axis means the picture ends where
/// the frame does and there is nothing on that axis to move to.
@visibleForTesting
Size artOverflow({required Size frame, required Size image}) {
  if (frame.isEmpty || image.isEmpty) return Size.zero;
  final scale = math.max(
    frame.width / image.width,
    frame.height / image.height,
  );
  return Size(
    math.max(0, image.width * scale - frame.width),
    math.max(0, image.height * scale - frame.height),
  );
}

/// Hold, then drag to move the picture inside its frame.
///
/// Offered only where it does something. A card earns the control by having a
/// picture genuinely larger than its frame — not merely by having a url. A
/// picture that failed to load, or one whose proportions already match the
/// frame, has nothing to reveal, and a control that answers a deliberate hold
/// with no movement reads as broken.
///
/// The hold is what lets the card sit in a scrolling page. A plain drag on the
/// picture competes with the page's own: the page wins a vertical swipe, which
/// is right, but it leaves the owner able to move the art sideways and never up
/// or down. Waiting for a hold takes the picture out of that contest — an
/// ordinary swipe still scrolls, and a deliberate one moves both axes.
class ArtFramingGesture extends StatefulWidget {
  const ArtFramingGesture({
    super.key,
    required this.imageUrl,
    required this.framing,
    required this.onChanged,
    required this.builder,
  });

  final String imageUrl;
  final ArtFraming framing;
  final ValueChanged<ArtFraming> onChanged;

  /// Builds the art at the framing to paint — the in-flight one while the owner
  /// is moving it, the recorded one otherwise.
  final Widget Function(BuildContext context, ArtFraming framing) builder;

  @override
  State<ArtFramingGesture> createState() => _ArtFramingGestureState();
}

class _ArtFramingGestureState extends State<ArtFramingGesture> {
  /// The picture's own dimensions, or null until it has loaded — and forever if
  /// it never does.
  Size? _image;

  ImageStream? _stream;
  ImageStreamListener? _listener;

  /// The framing the finger is on. Held past the release so the picture does
  /// not step back while the session records it.
  ArtFraming? _live;

  bool _holding = false;
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

  Size get _overflow {
    final image = _image;
    if (image == null) return Size.zero;
    return artOverflow(frame: _frame, image: image);
  }

  /// Whether there is enough of the picture outside the frame to be worth
  /// moving to. Sub-pixel slack is not.
  bool get _movable => _overflow.width > 1 || _overflow.height > 1;

  void _move(Offset delta) {
    final overflow = _overflow;
    final from = _live ?? widget.framing;
    setState(() {
      // The picture tracks the finger: a pixel of drag is a pixel of picture.
      // Dragging right pulls the picture right, which brings the part to its
      // left into view — so the point being looked at moves the other way.
      _live = from.shifted(
        dx: overflow.width == 0 ? 0 : -delta.dx / overflow.width,
        dy: overflow.height == 0 ? 0 : -delta.dy / overflow.height,
      );
    });
  }

  void _release() {
    if (mounted) setState(() => _holding = false);
    final settled = _live;
    if (settled != null && settled != widget.framing) {
      widget.onChanged(settled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = PersonalizationTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        _frame = constraints.biggest;
        final art = widget.builder(context, _live ?? widget.framing);
        if (!_movable) return art;
        return Semantics(
          label: AppLocalizations.of(context).profileArtFramingLabel,
          child: RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: {
              DelayedMultiDragGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    DelayedMultiDragGestureRecognizer
                  >(DelayedMultiDragGestureRecognizer.new, (recognizer) {
                    recognizer.onStart = (_) {
                      setState(() => _holding = true);
                      return _FramingDrag(onMove: _move, onEnd: _release);
                    };
                  }),
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                art,
                const ArtFramingBadge(),
                if (_holding)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: palette.accent,
                        width: PersonalizationLayout.borderWidth,
                      ),
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

/// The live drag handed back once the hold is recognised.
class _FramingDrag extends Drag {
  _FramingDrag({required this.onMove, required this.onEnd});

  final void Function(Offset delta) onMove;
  final VoidCallback onEnd;

  @override
  void update(DragUpdateDetails details) => onMove(details.delta);

  @override
  void end(DragEndDetails details) => onEnd();

  @override
  void cancel() => onEnd();
}

/// Marks a card whose picture the owner can move, drawn while editing.
///
/// The badge never takes the touch: it sits over the picture, and one that
/// caught the hold would swallow the gesture it exists to advertise.
class ArtFramingBadge extends StatelessWidget {
  const ArtFramingBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = PersonalizationTheme.of(context);
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Container(
            width: AppSpacing.xl,
            height: AppSpacing.xl,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.bg,
              border: Border.all(
                color: palette.accent,
                width: PersonalizationLayout.borderWidth,
              ),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(
              Icons.open_with,
              size: AppSpacing.md,
              color: palette.text,
            ),
          ),
        ),
      ),
    );
  }
}
