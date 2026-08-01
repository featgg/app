import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../domain/profile_archetype.dart';
import '../domain/profile_composition.dart';
import '../domain/profile_layout.dart';
import '../domain/profile_widget.dart';
import 'art_framing_control.dart';
import 'composition_drop_zones.dart';
import 'personalization_archetype_cards.dart';
import 'profile_composition_controller.dart';
import 'profile_widgets_controller.dart';
import 'profile_widgets_provider.dart';

/// The draggable rows region shown while the owner is editing their composition.
/// Measures the gaps between rows and the rows a lifted card may pair with,
/// hands the nearest of them to the drag — so a release near a landing place
/// lands there rather than demanding a pointer-exact hover — and marks that one
/// landing place and nothing else. Wires the drag lifecycle to
/// [ProfileComposition] and offers the size toggle on any card that supports
/// both sizes. Disabled cards stay visible and draggable so their slot is
/// preserved through the save.
class CompositionEditorRows extends ConsumerStatefulWidget {
  const CompositionEditorRows({super.key, required this.columnWidth});

  final double columnWidth;

  @override
  ConsumerState<CompositionEditorRows> createState() =>
      _CompositionEditorRowsState();
}

class _CompositionEditorRowsState extends ConsumerState<CompositionEditorRows>
    with SingleTickerProviderStateMixin {
  // Everything below is born and dies inside one drag and is read nowhere else;
  // every consequence of it goes through the composition controller.
  //
  // The id currently lifted, or null.
  String? _draggingId;

  // The landing place the drag holds, and — for a pair — which side of the
  // target card. The two always move together.
  DropZone? _acquired;
  DropSide? _acquiredSide;

  // Where the finger is, in global coordinates.
  Offset? _point;

  final GlobalKey _regionKey = GlobalKey();
  final Map<int, GlobalKey> _gapKeys = {};

  // Positional, never card-id-keyed: a duplicate GlobalKey is a crash, and a
  // persisted layout carrying a duplicate id today merely renders twice.
  final Map<(int, int), GlobalKey> _slotKeys = {};

  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: PersonalizationLayout.editorMarkPulse,
    );
    // Starts at full strength and breathes down, so a mark never appears
    // mid-fade on a drag too short to complete a cycle.
    _pulse = _pulseController.drive(
      Tween<double>(
        begin: 1,
        end: PersonalizationLayout.editorMarkPulseFloor,
      ).chain(CurveTween(curve: Curves.easeInOut)),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  GlobalKey _gapKey(int index) => _gapKeys.putIfAbsent(index, GlobalKey.new);

  GlobalKey _slotKey(int rowIndex, int slotIndex) =>
      _slotKeys.putIfAbsent((rowIndex, slotIndex), GlobalKey.new);

  Set<ProfileCardSize> _sizesOf(String id, Map<String, ProfileWidget> byId) {
    final widget = byId[id];
    return widget == null
        ? const {ProfileCardSize.full}
        : supportedSizes(archetypeForWidget(widget));
  }

  /// Half-support as the zones the drag is scored against read it.
  CardSizeSupport _halfSupport(Map<String, ProfileWidget> byId) =>
      (id) => _sizesOf(id, byId).contains(ProfileCardSize.half);

  Map<String, ProfileWidget> _widgetsById() {
    final widgets = ref.read(ownerProfileWidgetsProvider).value ?? const [];
    return {for (final w in widgets) w.id: w};
  }

  /// Nudge the surrounding scroll view when the pointer nears a viewport edge.
  void _autoScroll(Offset point) {
    final position = Scrollable.maybeOf(context)?.position;
    final media = MediaQuery.maybeOf(context);
    if (position == null || media == null) return;
    final y = point.dy;
    const band = AppSpacing.xl * 3;
    const step = PersonalizationLayout.rowGap;
    if (y < band && position.pixels > position.minScrollExtent) {
      position.jumpTo(
        math.max(position.minScrollExtent, position.pixels - step),
      );
    } else if (y > media.size.height - band &&
        position.pixels < position.maxScrollExtent) {
      position.jumpTo(
        math.min(position.maxScrollExtent, position.pixels + step),
      );
    }
  }

  /// Anchors the lifted card on the pointer — the answer
  /// [pointerDragAnchorStrategy] gives — and records where the press was on the
  /// way through. This is the only place the drag reports where it began, and
  /// the update details cannot stand in for it: an update carries the press
  /// point when it is the one that started the drag and the live position
  /// otherwise, and the two are indistinguishable from the details alone.
  Offset _liftFrom(
    Draggable<Object> draggable,
    BuildContext context,
    Offset position,
  ) {
    _point = position;
    return Offset.zero;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final start = _point;
    if (start == null) return;
    // The press point plus every delta since, which is the drag avatar's own
    // accounting — so the card riding under the finger and the zone being
    // scored are read off the same position.
    final point = start + details.delta;
    _point = point;
    _autoScroll(point);
    _acquire(point);
  }

  /// The box [key] renders, in the rows region's coordinates.
  Rect? _rectIn(RenderBox region, GlobalKey? key) {
    final box = key?.currentContext?.findRenderObject() as RenderBox?;
    // A card deleted while its key was cached has no context left.
    if (box == null || !box.hasSize) return null;
    return region.globalToLocal(box.localToGlobal(Offset.zero)) & box.size;
  }

  /// Every landing place [dragId] currently has. Re-measured on each move: the
  /// gaps grow when the drag starts and the page auto-scrolls under the finger,
  /// so a set measured once at lift would describe a layout that is gone.
  List<DropZone> _zones(String dragId, RenderBox region) {
    final working = ref.read(profileCompositionProvider).working;
    final supportsHalf = _halfSupport(_widgetsById());
    final zones = <DropZone>[];
    for (var i = 0; i <= working.length; i++) {
      final rect = _rectIn(region, _gapKeys[i]);
      if (rect != null) zones.add(GapZone(index: i, rect: rect));
    }
    for (var i = 0; i < working.length; i++) {
      final targetId = pairTargetAt(
        working,
        i,
        dragId,
        supportsHalf: supportsHalf,
      );
      // A row offering nothing contributes no zone at all, so a release over it
      // falls to the nearest gap instead of reading as dead.
      if (targetId == null) continue;
      final slotIndex = switch (working[i]) {
        FullRow() => 0,
        PairRow(:final left) => left == targetId ? 0 : 1,
      };
      final card = _rectIn(region, _slotKeys[(i, slotIndex)]);
      if (card == null) continue;
      zones.add(
        PairZone(
          targetId: targetId,
          cardCenterX: card.center.dx,
          rect: Rect.fromLTRB(0, card.top, region.size.width, card.bottom),
        ),
      );
    }
    return zones;
  }

  void _acquire(Offset globalPoint) {
    final dragId = _draggingId;
    final region = _regionKey.currentContext?.findRenderObject() as RenderBox?;
    if (dragId == null || region == null || !region.hasSize) return;
    final point = region.globalToLocal(globalPoint);
    final zone = resolveDropZone(
      point: point,
      bounds: Offset.zero & region.size,
      zones: _zones(dragId, region),
      current: _acquired,
    );
    final held = _acquired;
    final side = zone is PairZone
        ? zone.sideFor(
            point,
            // A side is only held against the same target card; landing on a
            // new one chooses its side fresh.
            current: held is PairZone && held.targetId == zone.targetId
                ? _acquiredSide
                : null,
          )
        : null;
    if (zone == _acquired && side == _acquiredSide) return;
    // Each change of target is felt, so the owner knows what a release will do
    // without looking away from the card they are carrying.
    if (zone != null) HapticFeedback.selectionClick();
    setState(() {
      _acquired = zone;
      _acquiredSide = side;
    });
  }

  /// The release. Fires on both endings of a drag, so nothing held means a
  /// clean cancel and an untouched layout.
  void _drop() {
    // Stops the ticker and leaves the marks at their static full strength.
    _pulseController.reset();
    final dragId = _draggingId;
    final zone = _acquired;
    final side = _acquiredSide;
    setState(() {
      _draggingId = null;
      _acquired = null;
      _acquiredSide = null;
      _point = null;
    });
    if (dragId == null || zone == null) return;
    // The layout can change under a held acquisition — the delete affordance
    // stays live through a drag, and a second finger reaches it — so what was
    // acquired is re-checked against the layout as it is now. A landing place
    // that is gone cancels the release rather than being nudged onto another
    // one: a card must never land somewhere its owner did not aim it.
    final working = ref.read(profileCompositionProvider).working;
    final composition = ref.read(profileCompositionProvider.notifier);
    switch (zone) {
      case GapZone(:final index):
        if (index > working.length) return;
        composition.onGapDrop(dragId, index);
      case PairZone(:final targetId):
        if (!layoutHolds(working, targetId)) return;
        composition.onPairDrop(dragId, targetId, side!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final working = ref.watch(
      profileCompositionProvider.select((s) => s.working),
    );
    // The delete affordance is disabled while a save is in flight, parity with
    // the disabled Cancel/Add in the app bar.
    final saving = ref.watch(
      profileCompositionProvider.select((s) => s.saving),
    );
    final widgets = ref.watch(ownerProfileWidgetsProvider).value ?? const [];
    // Edit mode builds from every owner widget, including disabled ones.
    final byId = {for (final w in widgets) w.id: w};
    final palette = PersonalizationTheme.of(context);
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    bool supportsBoth(String id) =>
        _sizesOf(id, byId).contains(ProfileCardSize.half) &&
        _sizesOf(id, byId).contains(ProfileCardSize.full);

    final children = <Widget>[
      // The drag hint lives here now that no floating bar hosts it: a bounded
      // caption that soft-wraps within the fixed column instead of pushing a
      // control row past a narrow screen.
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          l10n.profileComposeHint,
          style: textTheme.labelSmall?.copyWith(color: palette.muted),
        ),
      ),
      _gap(0, palette),
    ];
    for (var i = 0; i < working.length; i++) {
      children.add(
        _row(
          working[i],
          i,
          byId,
          palette,
          saving: saving,
          supportsBoth: supportsBoth,
        ),
      );
      children.add(_gap(i + 1, palette));
    }

    // Marks every card below as the owner's to reframe. The read view builds
    // the same cards from the same builder and does not provide this, which is
    // what makes a visitor's copy of the card inert.
    return ArtFramingScope(
      activeId: ref.watch(
        profileCompositionProvider.select((s) => s.framingId),
      ),
      onActivate: (id) =>
          ref.read(profileCompositionProvider.notifier).setFramingTarget(id),
      onChanged: (id, framing) {
        final target = byId[id];
        if (target == null) return;
        ref
            .read(profileCompositionProvider.notifier)
            .setFraming(id, was: target.framing, now: framing);
      },
      child: Column(
        key: _regionKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _gap(int index, PersonalizationPalette palette) {
    final dragging = _draggingId != null;
    final acquired = _acquired;
    final active = acquired is GapZone && acquired.index == index;
    // KeyedSubtree carries no render object of its own, so the measured box is
    // the Container's and the gap key stays where it has always been.
    return KeyedSubtree(
      key: _gapKey(index),
      child: Container(
        key: Key('compositionGap_$index'),
        height: dragging ? AppSpacing.lg : PersonalizationLayout.rowGap,
        alignment: Alignment.center,
        child: active
            ? _Pulse(
                animation: _pulse,
                child: Container(
                  key: Key('compositionMark_gap_$index'),
                  height: AppSpacing.hairline * 2,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: palette.accent,
                    borderRadius: BorderRadius.circular(AppRadii.full),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _row(
    ProfileLayoutRow row,
    int rowIndex,
    Map<String, ProfileWidget> byId,
    PersonalizationPalette palette, {
    required bool saving,
    required bool Function(String) supportsBoth,
  }) {
    return switch (row) {
      FullRow(:final cardId) => _slot(
        cardId,
        rowIndex,
        0,
        ProfileCardSize.full,
        byId,
        palette,
        saving: saving,
        supportsBoth: supportsBoth,
      ),
      PairRow(:final left, :final right) => personalizationPairFrame(
        left: left == null
            ? null
            : _slot(
                left,
                rowIndex,
                0,
                ProfileCardSize.half,
                byId,
                palette,
                saving: saving,
                supportsBoth: supportsBoth,
              ),
        right: right == null
            ? null
            : _slot(
                right,
                rowIndex,
                1,
                ProfileCardSize.half,
                byId,
                palette,
                saving: saving,
                supportsBoth: supportsBoth,
              ),
      ),
    };
  }

  Widget _slot(
    String cardId,
    int rowIndex,
    int slotIndex,
    ProfileCardSize size,
    Map<String, ProfileWidget> byId,
    PersonalizationPalette palette, {
    required bool saving,
    required bool Function(String) supportsBoth,
  }) {
    final stored = byId[cardId];
    if (stored == null) return const SizedBox.shrink();
    // The session's framing, where the owner has moved one this session. The
    // card is built from the same builder the read view uses, so the working
    // value has to reach it on the widget rather than beside it.
    final working = ref.watch(
      profileCompositionProvider.select((s) => s.framings[cardId]),
    );
    final widget = working == null ? stored : stored.copyWith(framing: working);
    final l10n = AppLocalizations.of(context);
    final acquired = _acquired;
    final marked = acquired is PairZone && acquired.targetId == cardId;

    final slot = Stack(
      key: _slotKey(rowIndex, slotIndex),
      children: [
        // Owner cards (cardSource null); member-since is unused in edit mode.
        personalizationCardFor(widget, size: size),
        if (marked)
          Positioned(
            top: PersonalizationLayout.editorMarkBarInset,
            bottom: PersonalizationLayout.editorMarkBarInset,
            left: _acquiredSide == DropSide.left ? AppSpacing.xs : null,
            right: _acquiredSide == DropSide.right ? AppSpacing.xs : null,
            width: AppSpacing.hairline * 2,
            child: IgnorePointer(
              child: _Pulse(
                animation: _pulse,
                child: DecoratedBox(
                  key: Key('compositionMark_pair_$cardId'),
                  decoration: BoxDecoration(
                    color: palette.accent,
                    borderRadius: BorderRadius.circular(AppRadii.full),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        Positioned(
          top: AppSpacing.xs,
          left: AppSpacing.xs,
          child: _handle(widget, size, palette, l10n),
        ),
        Positioned(
          top: AppSpacing.xs,
          right: AppSpacing.xs,
          child: _DeleteButton(
            // Identity key scopes the button's single-fire State to this card, so
            // positional row reuse never re-homes a deleted card's `_busy == true`
            // onto the successor that slides into its slot (would deaden its
            // delete). A local ValueKey — not a GlobalKey — disambiguates siblings.
            key: ValueKey('deleteFor_$cardId'),
            cardId: cardId,
            saving: saving,
            palette: palette,
            label: l10n.profileComposeDeleteLabel,
            // Mirror of the Add flow: drop the card from the working layout AND
            // delete the acquired widget. The widget delete invalidates the read;
            // the settled refetch no longer contains it, so the reactive add-only
            // fold never re-appends it (no bounce-back).
            onDelete: () {
              ref
                  .read(profileCompositionProvider.notifier)
                  .removeCardFromLayout(cardId);
              ref
                  .read(profileWidgetsControllerProvider.notifier)
                  .remove(cardId);
            },
          ),
        ),
        if (supportsBoth(cardId))
          Positioned(
            bottom: AppSpacing.xs,
            right: AppSpacing.xs,
            child: _sizeToggle(cardId, palette, l10n),
          ),
      ],
    );

    if (_draggingId != cardId) return slot;
    // The card is in the air; the slot it left reads vacated.
    return Opacity(
      opacity: PersonalizationLayout.editorOriginOpacity,
      child: slot,
    );
  }

  Widget _handle(
    ProfileWidget card,
    ProfileCardSize size,
    PersonalizationPalette palette,
    AppLocalizations l10n,
  ) {
    final cardId = card.id;
    final icon = Container(
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
        Icons.drag_indicator,
        size: AppSpacing.md,
        color: palette.text,
      ),
    );

    return Semantics(
      label: l10n.profileComposeDragHandleLabel,
      button: true,
      child: Draggable<String>(
        key: Key('compositionDragHandle_$cardId'),
        data: cardId,
        // The finger decides the acquisition, so the card has to be symmetric
        // around it rather than hanging off the grab point.
        dragAnchorStrategy: _liftFrom,
        onDragStarted: () {
          setState(() => _draggingId = cardId);
          // Reduced motion opts out of the ticker itself, not just of its
          // effect.
          if (!MediaQuery.disableAnimationsOf(context)) {
            _pulseController.repeat(reverse: true);
          }
        },
        onDragUpdate: _onDragUpdate,
        // Fires on both endings, so the release is decided in one place.
        onDragEnd: (_) => _drop(),
        feedback: _lifted(card, size, palette),
        child: icon,
      ),
    );
  }

  /// The card itself, in the air: the same card the slot renders, capped and
  /// centred on the finger.
  Widget _lifted(
    ProfileWidget card,
    ProfileCardSize size,
    PersonalizationPalette palette,
  ) {
    final slotWidth = size == ProfileCardSize.half
        ? (widget.columnWidth - PersonalizationLayout.rowGap) / 2
        : widget.columnWidth;
    // The feedback builds inside the Overlay, above the page and so outside the
    // profile's palette scope, and every card asserts a palette ancestor.
    return PersonalizationTheme(
      palette: palette,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Material(
          type: MaterialType.transparency,
          child: Opacity(
            opacity: PersonalizationLayout.editorGhostOpacity,
            child: SizedBox(
              width: math.min(
                slotWidth,
                PersonalizationLayout.editorGhostMaxWidth,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(palette.radius),
                  boxShadow: PersonalizationLift.shadows,
                ),
                child: personalizationCardFor(card, size: size),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sizeToggle(
    String cardId,
    PersonalizationPalette palette,
    AppLocalizations l10n,
  ) {
    return InkWell(
      key: Key('compositionSizeToggle_$cardId'),
      onTap: () =>
          ref.read(profileCompositionProvider.notifier).onToggleSize(cardId),
      borderRadius: BorderRadius.circular(AppRadii.full),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: palette.bg,
          border: Border.all(
            color: palette.accent,
            width: PersonalizationLayout.borderWidth,
          ),
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
        child: Semantics(
          label: l10n.profileComposeSizeToggleLabel,
          button: true,
          child: Icon(
            Icons.swap_horiz,
            size: AppSpacing.md,
            color: palette.text,
          ),
        ),
      ),
    );
  }
}

/// Breathes the landing indicator while a card is in the air. Wraps the mark
/// only — the rows never rebuild for it — and steps aside entirely where the
/// platform asks for reduced motion, leaving the mark at full strength.
class _Pulse extends StatelessWidget {
  const _Pulse({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery.disableAnimationsOf(context)
      ? child
      : RepaintBoundary(
          child: FadeTransition(opacity: animation, child: child),
        );
}

/// The per-card delete affordance. Stateful with a per-instance single-fire
/// [_DeleteButtonState._busy] flag so a same-frame double-tap dispatches the
/// removal at most once (mirrors the add row's busy-guard). The first tap
/// synchronously drops the card from the working layout, so this button is
/// disposed on the next rebuild — the flag needs no reset and no async write, and
/// a re-appeared card (a failed delete folded back) gets a fresh, deletable
/// instance.
class _DeleteButton extends StatefulWidget {
  const _DeleteButton({
    super.key,
    required this.cardId,
    required this.saving,
    required this.onDelete,
    required this.palette,
    required this.label,
  });

  final String cardId;
  final bool saving;
  final VoidCallback onDelete;
  final PersonalizationPalette palette;
  final String label;

  @override
  State<_DeleteButton> createState() => _DeleteButtonState();
}

class _DeleteButtonState extends State<_DeleteButton> {
  // Single-fire; never reset, never written in an async callback. The button
  // self-disposes on the post-delete rebuild, so it only blocks a same-frame
  // second tap before the element is torn down.
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return Semantics(
      label: widget.label,
      button: true,
      child: InkWell(
        key: Key('compositionDelete_${widget.cardId}'),
        onTap: widget.saving
            ? null
            : () {
                if (_busy) return; // blocks a same-frame second tap
                _busy = true; // no setState: the button self-disposes
                widget.onDelete();
              },
        borderRadius: BorderRadius.circular(AppRadii.sm),
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
            Icons.delete_outline,
            size: AppSpacing.md,
            color: palette.text,
          ),
        ),
      ),
    );
  }
}
