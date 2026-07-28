import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../core/error/failure.dart';
import '../domain/profile.dart';
import 'owner_profile_personalization.dart';
import 'personalization_theme_palette.dart';
import 'profile_composition_controller.dart';
import 'profile_provider.dart';
import 'profile_widgets_controller.dart';
import 'profile_widgets_provider.dart';
import 'showcase_picker.dart';

/// Displays the signed-in user's own profile.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(profileProvider);
    // The composition-side inputs to the mount gate and the compose app bar.
    // Selecting the fields (not the whole state) keeps the screen from rebuilding
    // on every drag; saving/isDirty gate the edit-mode Done action.
    final compose = ref.watch(
      profileCompositionProvider.select(
        (s) => (
          editing: s.editing,
          hasPersisted: s.hasPersisted,
          savedIsNotEmpty: s.saved.isNotEmpty,
          saving: s.saving,
          isDirty: s.isDirty,
        ),
      ),
    );
    // Backs the edit-layout gate (canEdit) and supplies the add sheet's widget
    // list; the compose app bar lives on this Scaffold, so the read is here.
    final widgetsState = ref.watch(ownerProfileWidgetsProvider);
    // Observe the widget-mutation controller here: the screen outlives every
    // grid tile and the add button, so this listener keeps the autoDispose
    // controller alive across an in-flight mutation (its post-await invalidate
    // fires and the grid refreshes) and surfaces a failure as a SnackBar.
    ref.listen<AsyncValue<void>>(profileWidgetsControllerProvider, (
      previous,
      next,
    ) {
      if (!context.mounted || !next.hasError) return;
      final error = next.error!;
      final msg = error is Failure
          ? error.localizedMessage(l10n)
          : l10n.errorUnexpected;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            key: const Key('profileWidgetsErrorSnackBar'),
            content: Text(msg),
          ),
        );
    });
    // Settings entry: refresh the profile read on any return (app-bar back,
    // system back, or swipe), since only the app-bar button delivers a typed pop
    // result — relying on it left the privacy indicator stale after a
    // system/gesture back. The refresh is cheap and shows no loading flash (the
    // profile read keeps its previous value on reload).
    IconButton settingsAction() => IconButton(
      key: const Key('settingsEntryButton'),
      icon: const Icon(Icons.settings_outlined),
      tooltip: l10n.settingsTitle,
      onPressed: () async {
        await context.push('/settings');
        if (!context.mounted) return;
        ref.invalidate(profileProvider);
      },
    );

    // Disabled while the read is refreshing. The form is seeded from the
    // profile handed to it and writes every field back, so opening it on a
    // value known to be stale — the window right after Settings is dismissed —
    // would let a save revert what was just changed there.
    IconButton editProfileAction(Profile p) => IconButton(
      key: const Key('profileEditButton'),
      icon: const Icon(Icons.edit_outlined),
      tooltip: l10n.profileEdit,
      onPressed: state.isRefreshing
          ? null
          : () => context.push('/profile/edit', extra: p),
    );

    // The composed surface hosts its compose controls in the app bar so nothing
    // floats over the render.
    final profile = state.hasValue ? state.value : null;

    final PreferredSizeWidget appBar;
    if (profile == null) {
      // Loading or errored: the standard app bar, with only the action that
      // needs no profile.
      appBar = AppBar(
        title: Text(l10n.profileTitle),
        actions: [settingsAction()],
      );
    } else {
      // Themed to the profile palette so the chrome never clashes with the
      // render; controls are icon actions (immune to translation length, which
      // is what collapsed the old floating bar on a narrow screen).
      final palette = paletteForTheme(profile.theme);
      final notifier = ref.read(profileCompositionProvider.notifier);
      if (!compose.editing) {
        appBar = AppBar(
          backgroundColor: palette.bg,
          foregroundColor: palette.text,
          title: Text(l10n.profileTitle),
          actions: [
            settingsAction(),
            editProfileAction(profile),
            IconButton(
              key: const Key('profileComposeEditButton'),
              icon: const Icon(Icons.dashboard_customize_outlined),
              tooltip: l10n.profileComposeEdit,
              // Disabled until the owner widgets read settles (the seed needs it).
              onPressed: widgetsState.hasValue
                  ? () => notifier.startEditing(
                      profile.layout,
                      widgetsState.value!,
                    )
                  : null,
            ),
          ],
        );
      } else {
        appBar = AppBar(
          backgroundColor: palette.bg,
          foregroundColor: palette.text,
          automaticallyImplyLeading: false,
          leading: IconButton(
            key: const Key('profileComposeCancelButton'),
            icon: const Icon(Icons.close),
            tooltip: l10n.profileComposeCancel,
            onPressed: compose.saving ? null : notifier.cancelEditing,
          ),
          actions: [
            IconButton(
              key: const Key('profileComposeAddButton'),
              icon: const Icon(Icons.add),
              tooltip: l10n.profileComposeAdd,
              onPressed: compose.saving || !widgetsState.hasValue
                  ? null
                  : () => showShowcasePicker(
                      context,
                      existing: widgetsState.value!,
                    ),
            ),
            // While saving, the Done action becomes a themed spinner; Add and
            // Cancel are disabled so the sent snapshot can never change.
            if (compose.saving)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Center(
                  child: SizedBox(
                    width: AppSpacing.lg,
                    height: AppSpacing.lg,
                    child: CircularProgressIndicator(
                      strokeWidth: AppSpacing.hairline,
                      color: palette.text,
                    ),
                  ),
                ),
              )
            else
              IconButton(
                key: const Key('profileComposeDoneButton'),
                icon: const Icon(Icons.check),
                tooltip: l10n.profileComposeDone,
                onPressed: compose.isDirty ? notifier.save : null,
              ),
          ],
        );
      }
    }

    // In edit mode a system/predictive back cancels the composition (discard
    // edits) instead of leaving the profile — Cancel semantics. While saving the
    // sent snapshot is frozen, so back is inert; in view mode the pop proceeds.
    return PopScope(
      canPop: !compose.editing,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (compose.editing && !compose.saving) {
          ref.read(profileCompositionProvider.notifier).cancelEditing();
        }
      },
      child: Scaffold(
        appBar: appBar,
        body: SafeArea(
          child: AsyncValueWidget<Profile>(
            value: state,
            onRetry: () => ref.invalidate(profileProvider),
            loading: const ProfileSkeleton(),
            // One render for every owner profile. A profile with no saved
            // arrangement is not a different kind of profile — it renders the
            // same way, in the order the editor would seed.
            data: (profile) => OwnerProfilePersonalization(profile: profile),
          ),
        ),
      ),
    );
  }
}
