import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../domain/profile_archetype.dart';
import '../domain/profile_composition.dart';
import '../domain/profile_layout.dart';
import '../domain/profile_widget.dart';
import 'art_framing_control.dart';
import 'personalization_archetype_cards.dart';
import 'profile_composition_controller.dart';
import 'profile_widgets_controller.dart';
import 'profile_widgets_provider.dart';

/// The draggable rows region shown while the owner is editing their composition.
/// Interleaves gap drop zones between rows and side drop zones on each card, wires
/// the drag lifecycle to [ProfileComposition], and offers the size toggle on any
/// card that supports both sizes. Disabled cards stay visible and draggable so
/// their slot is preserved through the save.
class CompositionEditorRows extends ConsumerStatefulWidget {
  const CompositionEditorRows({super.key, required this.columnWidth});

  final double columnWidth;

  @override
  ConsumerState<CompositionEditorRows> createState() =>
      _CompositionEditorRowsState();
}

class _CompositionEditorRowsState extends ConsumerState<CompositionEditorRows> {
  // The id currently lifted, or null. Ephemeral UI state driving the glow.
  String? _draggingId;

  Set<ProfileCardSize> _sizesOf(String id, Map<String, ProfileWidget> byId) {
    final widget = byId[id];
    return widget == null
        ? const {ProfileCardSize.full}
        : supportedSizes(archetypeForWidget(widget));
  }

  /// Nudge the surrounding scroll view when the pointer nears a viewport edge.
  void _autoScroll(DragUpdateDetails details) {
    final position = Scrollable.maybeOf(context)?.position;
    final media = MediaQuery.maybeOf(context);
    if (position == null || media == null) return;
    final y = details.globalPosition.dy;
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

    bool supportsHalf(String id) =>
        _sizesOf(id, byId).contains(ProfileCardSize.half);
    bool supportsBoth(String id) =>
        _sizesOf(id, byId).contains(ProfileCardSize.half) &&
        _sizesOf(id, byId).contains(ProfileCardSize.full);

    final glowRows = _draggingId == null
        ? const <int>{}
        : pairableRowIndices(working, _draggingId!, supportsHalf: supportsHalf);

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
          supportsHalf: supportsHalf,
          supportsBoth: supportsBoth,
          glowing: glowRows.contains(i),
        ),
      );
      children.add(_gap(i + 1, palette));
    }

    // Marks every card below as the owner's to reframe. The read view builds
    // the same cards from the same builder and does not provide this, which is
    // what makes a visitor's copy of the card inert.
    return ArtFramingScope(
      onChanged: (id, framing) {
        final target = byId[id];
        if (target == null) return;
        ref
            .read(profileCompositionProvider.notifier)
            .setFraming(id, was: target.framing, now: framing);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _gap(int index, PersonalizationPalette palette) {
    final dragging = _draggingId != null;
    return DragTarget<String>(
      // Any card can become its own row in a gap.
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => ref
          .read(profileCompositionProvider.notifier)
          .onGapDrop(details.data, index),
      builder: (context, candidate, rejected) {
        final active = candidate.isNotEmpty;
        return Container(
          key: Key('compositionGap_$index'),
          height: dragging ? AppSpacing.lg : PersonalizationLayout.rowGap,
          alignment: Alignment.center,
          child: active
              ? Container(
                  height: AppSpacing.hairline * 2,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: palette.accent,
                    borderRadius: BorderRadius.circular(AppRadii.full),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _row(
    ProfileLayoutRow row,
    int rowIndex,
    Map<String, ProfileWidget> byId,
    PersonalizationPalette palette, {
    required bool saving,
    required bool Function(String) supportsHalf,
    required bool Function(String) supportsBoth,
    required bool glowing,
  }) {
    final content = switch (row) {
      FullRow(:final cardId) => _slot(
        cardId,
        rowIndex,
        ProfileCardSize.full,
        byId,
        palette,
        saving: saving,
        supportsHalf: supportsHalf,
        supportsBoth: supportsBoth,
      ),
      PairRow(:final left, :final right) => personalizationPairFrame(
        left: left == null
            ? null
            : _slot(
                left,
                rowIndex,
                ProfileCardSize.half,
                byId,
                palette,
                saving: saving,
                supportsHalf: supportsHalf,
                supportsBoth: supportsBoth,
              ),
        right: right == null
            ? null
            : _slot(
                right,
                rowIndex,
                ProfileCardSize.half,
                byId,
                palette,
                saving: saving,
                supportsHalf: supportsHalf,
                supportsBoth: supportsBoth,
              ),
      ),
    };

    if (!glowing) return content;
    // A valid pair destination glows while a card is lifted.
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: palette.accent,
          width: PersonalizationLayout.borderWidth,
        ),
        borderRadius: BorderRadius.circular(palette.radius),
      ),
      child: content,
    );
  }

  Widget _slot(
    String cardId,
    int rowIndex,
    ProfileCardSize size,
    Map<String, ProfileWidget> byId,
    PersonalizationPalette palette, {
    required bool saving,
    required bool Function(String) supportsHalf,
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

    return Stack(
      children: [
        // Owner cards (cardSource null); member-since is unused in edit mode.
        personalizationCardFor(widget, size: size),
        Positioned.fill(
          child: Row(
            children: [
              Expanded(
                child: _sideTarget(
                  rowIndex,
                  cardId,
                  DropSide.left,
                  palette,
                  supportsHalf: supportsHalf,
                ),
              ),
              Expanded(
                child: _sideTarget(
                  rowIndex,
                  cardId,
                  DropSide.right,
                  palette,
                  supportsHalf: supportsHalf,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: AppSpacing.xs,
          left: AppSpacing.xs,
          child: _handle(cardId, palette, l10n),
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
  }

  Widget _sideTarget(
    int rowIndex,
    String targetId,
    DropSide side,
    PersonalizationPalette palette, {
    required bool Function(String) supportsHalf,
  }) {
    return DragTarget<String>(
      // Read the live working layout at hit-test time.
      onWillAcceptWithDetails: (details) => canPairBeside(
        ref.read(profileCompositionProvider).working,
        rowIndex,
        details.data,
        targetId,
        supportsHalf: supportsHalf,
      ),
      onAcceptWithDetails: (details) => ref
          .read(profileCompositionProvider.notifier)
          .onPairDrop(details.data, targetId, side),
      builder: (context, candidate, rejected) {
        if (candidate.isEmpty) return const SizedBox.expand();
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: side == DropSide.left
                  ? BorderSide(
                      color: palette.accent,
                      width: AppSpacing.hairline,
                    )
                  : BorderSide.none,
              right: side == DropSide.right
                  ? BorderSide(
                      color: palette.accent,
                      width: AppSpacing.hairline,
                    )
                  : BorderSide.none,
            ),
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }

  Widget _handle(
    String cardId,
    PersonalizationPalette palette,
    AppLocalizations l10n,
  ) {
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
        onDragStarted: () => setState(() => _draggingId = cardId),
        onDragUpdate: _autoScroll,
        onDragEnd: (_) => setState(() => _draggingId = null),
        onDraggableCanceled: (_, _) => setState(() => _draggingId = null),
        feedback: _ghost(palette),
        child: icon,
      ),
    );
  }

  Widget _ghost(PersonalizationPalette palette) {
    return Material(
      type: MaterialType.transparency,
      child: Opacity(
        opacity: PersonalizationLayout.editorGhostOpacity,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: math.min(
              widget.columnWidth / 2,
              PersonalizationLayout.editorGhostMaxWidth,
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border.all(
              color: palette.accent,
              width: PersonalizationLayout.borderWidth,
            ),
            borderRadius: BorderRadius.circular(palette.radius),
          ),
          child: Icon(Icons.drag_indicator, color: palette.accent),
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
