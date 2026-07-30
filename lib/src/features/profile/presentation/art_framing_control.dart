import 'package:flutter/material.dart';

import '../domain/art_framing.dart';

/// Whose framing an art surface renders, so the surface can both apply it and,
/// where the owner is editing, write a new one back.
class ArtFramingTarget {
  const ArtFramingTarget({required this.widgetId, required this.framing});

  final String widgetId;
  final ArtFraming framing;
}

/// Marks the subtree the owner is editing, and carries the one call that
/// persists a reframe.
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

  final void Function(String widgetId, ArtFraming framing) onChanged;

  static ArtFramingScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ArtFramingScope>();

  @override
  bool updateShouldNotify(ArtFramingScope oldWidget) =>
      onChanged != oldWidget.onChanged;
}

/// Drag-to-reframe. The picture follows the finger while the owner drags and
/// the new point is persisted once, on release.
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
    required this.semanticsLabel,
    required this.builder,
  });

  final ArtFraming framing;
  final ValueChanged<ArtFraming> onChanged;
  final String semanticsLabel;

  /// Builds the art at the framing to paint — the in-flight one while dragging,
  /// the persisted one otherwise.
  final Widget Function(BuildContext context, ArtFraming framing) builder;

  @override
  State<ArtFramingGesture> createState() => _ArtFramingGestureState();
}

class _ArtFramingGestureState extends State<ArtFramingGesture> {
  /// The framing the finger is on, held past the release so the picture does
  /// not jump back to where it was while the write is in flight.
  ArtFraming? _live;

  @override
  void didUpdateWidget(ArtFramingGesture oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Anything upstream says — the write landing, a refetch, a failure putting
    // the old value back — outranks the local preview.
    if (oldWidget.framing != widget.framing) _live = null;
  }

  void _drag(DragUpdateDetails details, Size frame) {
    if (frame.isEmpty) return;
    final from = _live ?? widget.framing;
    setState(() {
      // Dragging right pulls the picture right, which brings the part to its
      // left into view — so the point being looked at moves the other way.
      _live = from.shifted(
        dx: -details.delta.dx / frame.width,
        dy: -details.delta.dy / frame.height,
      );
    });
  }

  void _release() {
    final settled = _live;
    if (settled != null && settled != widget.framing) {
      widget.onChanged(settled);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frame = constraints.biggest;
        return Semantics(
          label: widget.semanticsLabel,
          child: GestureDetector(
            // The pair-drop targets the editor stacks over a card do not claim
            // pointers, so the picture beneath them can still take the drag.
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) => _drag(details, frame),
            onPanEnd: (_) => _release(),
            onPanCancel: _release,
            child: widget.builder(context, _live ?? widget.framing),
          ),
        );
      },
    );
  }
}
