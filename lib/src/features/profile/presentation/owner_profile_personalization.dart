import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../domain/profile.dart';
import 'composition_editor_rows.dart';
import 'personalization_profile_view.dart';
import 'personalization_theme_palette.dart';
import 'profile_composition_controller.dart';
import 'profile_widgets_provider.dart';

/// The owner's view of their composed profile: the read-only personalization
/// render with an edit/save control bar overlaid. Entering edit mode swaps the
/// rows region for the composition editor; a save failure surfaces a snackbar and
/// rolls the working layout back.
class OwnerProfilePersonalization extends ConsumerWidget {
  const OwnerProfilePersonalization({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(profileCompositionProvider);
    final widgetsState = ref.watch(ownerProfileWidgetsProvider);

    // One-shot save-failure snackbar, then clear the flag.
    ref.listen(profileCompositionProvider.select((s) => s.saveFailed), (
      previous,
      failed,
    ) {
      if (!failed || !context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            key: const Key('profileComposeSaveFailedSnackBar'),
            content: Text(l10n.profileComposeSaveFailed),
          ),
        );
      ref.read(profileCompositionProvider.notifier).acknowledgeSaveFailure();
    });

    // Install the palette here too so the overlaid bar (a sibling of the render)
    // reads the same theme tokens the render uses.
    return PersonalizationTheme(
      palette: paletteForTheme(profile.theme),
      child: Stack(
        children: [
          PersonalizationProfileView(
            profile: profile,
            userId: profile.id,
            widgetsProvider: ownerProfileWidgetsProvider,
            rowsBuilder: state.editing
                ? (context, columnWidth) =>
                      CompositionEditorRows(columnWidth: columnWidth)
                : null,
            // Reserve room so the floating control bar never hides the last card.
            bottomInset: PersonalizationLayout.editorControlBarInset,
          ),
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: SafeArea(
              top: false,
              child: _ControlBar(
                editing: state.editing,
                saving: state.saving,
                canEdit: widgetsState.hasValue,
                canSave: state.isDirty,
                l10n: l10n,
                onEdit: () => ref
                    .read(profileCompositionProvider.notifier)
                    .startEditing(profile.layout, widgetsState.value!),
                onDone: () =>
                    ref.read(profileCompositionProvider.notifier).save(),
                onCancel: () => ref
                    .read(profileCompositionProvider.notifier)
                    .cancelEditing(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.editing,
    required this.saving,
    required this.canEdit,
    required this.canSave,
    required this.l10n,
    required this.onEdit,
    required this.onDone,
    required this.onCancel,
  });

  final bool editing;
  final bool saving;
  final bool canEdit;
  final bool canSave;
  final AppLocalizations l10n;
  final VoidCallback onEdit;
  final VoidCallback onDone;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final palette = PersonalizationTheme.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      key: const Key('profileComposeControlBar'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smMd,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(
          color: palette.line,
          width: PersonalizationLayout.borderWidth,
        ),
        borderRadius: BorderRadius.circular(palette.radius),
      ),
      child: Row(
        children: [
          if (editing) ...[
            Expanded(
              child: Text(
                l10n.profileComposeHint,
                style: textTheme.labelSmall?.copyWith(color: palette.muted),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _BarButton(
              buttonKey: const Key('profileComposeCancelButton'),
              label: l10n.profileComposeCancel,
              palette: palette,
              textTheme: textTheme,
              onTap: saving ? null : onCancel,
            ),
            const SizedBox(width: AppSpacing.sm),
            _BarButton(
              buttonKey: const Key('profileComposeDoneButton'),
              label: l10n.profileComposeDone,
              palette: palette,
              textTheme: textTheme,
              filled: true,
              busy: saving,
              onTap: canSave && !saving ? onDone : null,
            ),
          ] else
            _BarButton(
              buttonKey: const Key('profileComposeEditButton'),
              label: l10n.profileComposeEdit,
              palette: palette,
              textTheme: textTheme,
              filled: true,
              onTap: canEdit ? onEdit : null,
            ),
        ],
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.buttonKey,
    required this.label,
    required this.palette,
    required this.textTheme,
    required this.onTap,
    this.filled = false,
    this.busy = false,
  });

  final Key buttonKey;
  final String label;
  final PersonalizationPalette palette;
  final TextTheme textTheme;
  final VoidCallback? onTap;
  final bool filled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      key: buttonKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.full),
      child: Opacity(
        // A disabled action reads dimmer without a second color token.
        opacity: enabled ? 1 : PersonalizationLayout.controlDisabledOpacity,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: filled ? palette.accent : palette.accentSoft,
            border: Border.all(
              color: palette.accent,
              width: PersonalizationLayout.borderWidth,
            ),
            borderRadius: BorderRadius.circular(AppRadii.full),
          ),
          child: busy
              ? SizedBox(
                  width: AppSpacing.md,
                  height: AppSpacing.md,
                  child: CircularProgressIndicator(
                    strokeWidth: AppSpacing.hairline,
                    color: PersonalizationArtColors.onAccent,
                  ),
                )
              : Text(
                  label,
                  style: textTheme.labelMedium?.copyWith(
                    color: filled
                        ? PersonalizationArtColors.onAccent
                        : palette.text,
                    fontWeight: AppTypography.semiBold,
                  ),
                ),
        ),
      ),
    );
  }
}
