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

/// An explicit framing mode, entered from the mark on the card.
///
/// Tap the mark; the card enters framing; an ordinary one-finger drag moves the
/// picture, both axes; tap the mark again — or anywhere outside the card — to
/// leave. Inside the mode the card owns the gesture outright, so there is no
/// contest with the page; outside it the picture is inert and the page scrolls
/// exactly as it always did. Ownership, not delay: this replaced a hold that
/// existed only to survive the scroll contest, and that nothing else in the
/// industry uses for framing.
///
/// Offered only where it does something. A card earns the mark by having a
/// picture genuinely larger than its frame — not merely by having a url. A
/// picture that failed to load, or one whose proportions already match the
/// frame, has nothing to reveal, and a control that answers with no movement
/// reads as broken.
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

  /// Records where a drag left the picture.
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
        final art = widget.builder(context, _live ?? widget.framing);
        if (!_movable) return art;
        if (!widget.active) {
          // Inert but for the mark: the page keeps every gesture, so scrolling
          // over the card works exactly as it does over any other.
          return Stack(
            fit: StackFit.expand,
            children: [
              art,
              ArtFramingBadge(
                label: l10n.profileArtFramingStart,
                onTap: () => widget.onActiveChanged(true),
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
                  // A plain drag, uncontested: the mode holds the page still,
                  // so there is no recognizer left to out-wait. Competing for
                  // it was the earlier design, and the page won.
                  onPanUpdate: (details) => _move(details.delta),
                  onPanEnd: (_) => _release(),
                  onPanCancel: _release,
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
                ArtFramingBadge(
                  active: true,
                  label: l10n.profileArtFramingDone,
                  onTap: () => widget.onActiveChanged(false),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The mark on a card whose picture can be moved: the button that enters the
/// framing mode, and — [active] — the one that confirms and leaves it.
///
/// Centred while idle, because every corner of a card in the editor is already
/// spoken for — the handle, the delete, the size toggle, and the card's own
/// number in the fourth — and the middle is where a finger lands on a picture.
/// Once the mode is on, that same spot is where the drag begins, so the
/// confirm steps aside to the top edge instead of sitting on the gesture it
/// would otherwise swallow.
///
/// It sits above the drag layer on its own pixels only, so a drag starting
/// anywhere else on the picture never has to compete with it.
class ArtFramingBadge extends StatelessWidget {
  const ArtFramingBadge({
    super.key,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = PersonalizationTheme.of(context);
    return Align(
      alignment: active ? Alignment.topCenter : Alignment.center,
      child: Semantics(
        label: label,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.all(AppSpacing.xs),
            width: AppSpacing.xl,
            height: AppSpacing.xl,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? palette.accent : palette.bg,
              border: Border.all(
                color: palette.accent,
                width: PersonalizationLayout.borderWidth,
              ),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(
              active ? Icons.check : Icons.open_with,
              size: AppSpacing.md,
              color: active ? palette.accentText : palette.text,
            ),
          ),
        ),
      ),
    );
  }
}
