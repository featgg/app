import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../domain/art_framing.dart';

/// Whose framing an art surface renders, so the surface can both apply it and,
/// where the owner is editing, write a new one back.
class ArtFramingTarget {
  const ArtFramingTarget({required this.widgetId, required this.framing});

  final String widgetId;
  final ArtFraming framing;
}

/// Marks the subtree the owner is editing, and carries the one call that
/// persists a reframe. It reports whether the framing landed, which the
/// surface cannot infer: a successful write refreshes the profile
/// asynchronously, so "the stored value has not caught up yet" describes a
/// write in flight and a rejected one alike.
///
/// An inherited marker rather than a parameter threaded through every card:
/// the read view and the editor build cards from the same builder, and only the
/// enclosing surface knows which of the two it is.
class ArtFramingScope extends InheritedWidget {
  const ArtFramingScope({
    super.key,
    required this.onChanged,
    required super.child,
  });

  final Future<bool> Function(String widgetId, ArtFraming framing) onChanged;

  static ArtFramingScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ArtFramingScope>();

  @override
  bool updateShouldNotify(ArtFramingScope oldWidget) =>
      onChanged != oldWidget.onChanged;
}

/// Hold, then drag to reframe. The picture follows the finger and the new point
/// is persisted once, on release.
///
/// The hold is what lets the card sit in a scrolling page. A plain drag on the
/// picture competes with the page's own: the page wins a vertical swipe, which
/// is right, but it leaves the owner able to move the art sideways and never up
/// or down. Waiting for a hold takes the picture out of that contest — an
/// ordinary swipe still scrolls, and a deliberate one moves both axes.
///
/// A drag across the full frame travels the full picture, whatever the
/// picture's proportions. That keeps the control predictable — the owner always
/// knows how far there is left to go — and it degrades the right way: a picture
/// with barely more width than its frame has barely anything to reveal, and a
/// drag moves it barely at all.
class ArtFramingGesture extends StatefulWidget {
  const ArtFramingGesture({
    super.key,
    required this.framing,
    required this.onChanged,
    required this.builder,
  });

  final ArtFraming framing;

  /// Persists [framing] and reports whether it landed.
  final Future<bool> Function(ArtFraming framing) onChanged;

  /// Builds the art at the framing to paint — the in-flight one while the owner
  /// is moving it, the persisted one otherwise.
  final Widget Function(BuildContext context, ArtFraming framing) builder;

  @override
  State<ArtFramingGesture> createState() => _ArtFramingGestureState();
}

class _ArtFramingGestureState extends State<ArtFramingGesture> {
  /// The framing the finger is on, held past the release so the picture does
  /// not jump back to where it was while the write is in flight.
  ArtFraming? _live;

  /// Set while the owner has hold of the picture, which is what draws the mark
  /// saying so.
  bool _holding = false;

  /// Whether a write is in flight. A second release while one is running would
  /// race it, and the two can land out of order — leaving the framing the owner
  /// moved off as the stored one.
  bool _writing = false;

  /// What to write once the running write finishes. Only the newest matters:
  /// every framing between is a point the owner already moved off.
  ArtFraming? _queued;

  Size _frame = Size.zero;

  @override
  void didUpdateWidget(ArtFramingGesture oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Anything upstream says — the write landing, a refetch, a failure putting
    // the old value back — outranks the local preview.
    if (oldWidget.framing != widget.framing) _live = null;
  }

  void _move(Offset delta) {
    if (_frame.isEmpty) return;
    final from = _live ?? widget.framing;
    setState(() {
      // Dragging right pulls the picture right, which brings the part to its
      // left into view — so the point being looked at moves the other way.
      _live = from.shifted(
        dx: -delta.dx / _frame.width,
        dy: -delta.dy / _frame.height,
      );
    });
  }

  Future<void> _release() async {
    if (mounted) setState(() => _holding = false);
    final settled = _live;
    if (settled == null || settled == widget.framing) return;
    if (_writing) {
      _queued = settled;
      return;
    }
    _writing = true;
    var next = settled;
    bool landed;
    while (true) {
      landed = await widget.onChanged(next);
      if (!mounted) return;
      final queued = _queued;
      if (queued == null) break;
      _queued = null;
      next = queued;
    }
    _writing = false;
    // A framing that landed clears itself when the refreshed profile arrives.
    // One that did not would otherwise sit there forever: the stored value
    // never changes, so nothing else would ever take the preview down, and the
    // card would keep showing a crop nobody has.
    if (!landed && _live != null) setState(() => _live = null);
  }

  @override
  Widget build(BuildContext context) {
    final palette = PersonalizationTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        _frame = constraints.biggest;
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
                widget.builder(context, _live ?? widget.framing),
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
