import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../core/error/failure.dart';
import '../domain/profile.dart';
import 'avatar_picker.dart';
import 'avatar_upload_controller.dart';
import 'composition_editor_rows.dart';
import 'personalization_profile_view.dart';
import 'profile_composition_controller.dart';
import 'profile_edit_controls.dart';
import 'profile_header.dart';
import 'profile_widgets_provider.dart';

/// The owner's read/edit profile body. The same render either way — editing adds
/// the affordances over it rather than routing anywhere: the header's three
/// parts become tap targets, the theme strip appears, and the rows become
/// draggable. It owns no chrome — the edit/add/done/cancel controls live in the
/// screen's app bar. A save failure surfaces a snackbar and rolls the working
/// layout back.
class OwnerProfilePersonalization extends ConsumerWidget {
  const OwnerProfilePersonalization({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(
      profileCompositionProvider.select(
        (s) => (editing: s.editing, draft: s.editing ? s.draft : null),
      ),
    );
    // Watched in both modes so the auto-dispose upload controller outlives the
    // edit session: a success invalidates the profile read, and that must still
    // land if the owner leaves edit mode while the upload is in flight.
    final upload = ref.watch(avatarUploadControllerProvider);

    // Reactive append: while composing, fold every refetch of the owner's widgets
    // into the working layout so a card acquired from ANY channel (a Rank/Main
    // row, the passport row, another sheet, even another device) becomes
    // placeable once the invalidated read actually settles. This depends only on
    // the provider emitting, never on how or when the add sheet closed. The
    // append is idempotent and self-gated on edit + not-saving in the controller.
    // ProfileScreen (which owns this surface) keeps the mutation controller alive,
    // so a write's success-path invalidation reliably drives an emission here.
    ref.listen(ownerProfileWidgetsProvider, (previous, next) {
      // Only fold a SETTLED read. On invalidate Riverpod first re-delivers the
      // stale value as AsyncData(isRefreshing: true), which for a delete still
      // lists the just-removed widget — folding that would re-append it (bounce
      // back). Waiting for the settled read reflects the real acquire/delete.
      if (next case AsyncData(:final value) when !next.isRefreshing) {
        ref
            .read(profileCompositionProvider.notifier)
            .appendUnplacedWidgets(value);
      }
    });

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
            content: Text(l10n.profileEditSaveFailed),
          ),
        );
      ref.read(profileCompositionProvider.notifier).acknowledgeSaveFailure();
    });

    ref.listen(avatarUploadControllerProvider, (previous, next) {
      if (!context.mounted) return;
      if (next.status == AvatarUploadStatus.success) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              key: const Key('avatarUploadSuccessSnackBar'),
              content: Text(l10n.profileAvatarUpdated),
            ),
          );
      } else if (next.status == AvatarUploadStatus.error &&
          next.failure is RateLimitFailure &&
          next.cooldownUntil != null) {
        // A cooldown is a "not yet", not a failure to explain: it says when,
        // and says the same thing again on the next tap.
        _showCooldown(context, l10n, next.cooldownUntil!);
      } else if (next.status == AvatarUploadStatus.error &&
          next.failure != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              key: const Key('avatarUploadErrorSnackBar'),
              content: Text(next.failure!.localizedMessage(l10n)),
            ),
          );
      }
    });

    // What the owner is looking at while they edit: the profile as their unsaved
    // draft would leave it. One overlay here re-tints the palette, re-titles the
    // header and re-picks the cover, because everything below reads the profile
    // it is given rather than the one on the server.
    final draft = session.draft;
    final shown = draft == null
        ? profile
        : profile.copyWith(
            displayName: draft.displayName,
            bio: () => draft.bio,
            theme: draft.theme,
            headerPlatform: () => draft.headerPlatform,
          );

    final busy =
        upload.status == AvatarUploadStatus.picking ||
        upload.status == AvatarUploadStatus.uploading;

    return PersonalizationProfileView(
      profile: shown,
      userId: profile.id,
      widgetsProvider: ownerProfileWidgetsProvider,
      headerEditing: session.editing
          ? ProfileHeaderEditing(
              avatarBusy: busy,
              onEditAvatar: () {
                final cooldownUntil = ref
                    .read(avatarUploadControllerProvider)
                    .cooldownUntil;
                if (ref.read(avatarUploadControllerProvider).onCooldown &&
                    cooldownUntil != null) {
                  _showCooldown(context, l10n, cooldownUntil);
                  return;
                }
                ref
                    .read(avatarUploadControllerProvider.notifier)
                    .pickAndUpload(
                      () => ref.read(avatarPickerProvider).pickAndCrop(context),
                    );
              },
              onEditCover: () => showProfileCoverSheet(context),
              onEditIdentity: () => showProfileIdentitySheet(context),
            )
          : null,
      rowsBuilder: session.editing
          ? (context, columnWidth) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ProfileThemeStrip(),
                CompositionEditorRows(
                  columnWidth: columnWidth,
                  headerPlatform: shown.headerPlatform,
                  featuredPlatform: shown.featuredPlatform,
                ),
              ],
            )
          : null,
    );
  }
}

/// Tells the owner when the photo can change again, with the number correct at
/// the moment it is read rather than at the moment the limit was hit.
void _showCooldown(
  BuildContext context,
  AppLocalizations l10n,
  DateTime until,
) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        key: const Key('avatarCooldownSnackBar'),
        content: CooldownCountdown(
          until: until,
          label: (seconds) => l10n.profileAvatarCooldownCountdown(seconds),
        ),
      ),
    );
}
