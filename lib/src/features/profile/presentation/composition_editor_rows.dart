import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../domain/profile_archetype.dart';
import '../domain/profile_composition.dart';
import '../domain/profile_layout.dart';
import '../domain/profile_widget.dart';
import 'personalization_archetype_cards.dart';
import 'profile_composition_controller.dart';
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
          supportsHalf: supportsHalf,
          supportsBoth: supportsBoth,
          glowing: glowRows.contains(i),
        ),
      );
      children.add(_gap(i + 1, palette));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
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
    required bool Function(String) supportsHalf,
    required bool Function(String) supportsBoth,
  }) {
    final widget = byId[cardId];
    if (widget == null) return const SizedBox.shrink();
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
