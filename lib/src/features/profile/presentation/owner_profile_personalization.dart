import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../domain/profile.dart';
import 'composition_editor_rows.dart';
import 'personalization_profile_view.dart';
import 'profile_composition_controller.dart';
import 'profile_widgets_provider.dart';

/// The owner's read/edit personalization body: the read-only personalization
/// render, or the composition editor while editing. It owns no compose chrome —
/// the edit/add/done/cancel controls live in the screen's app bar. A save failure
/// surfaces a snackbar and rolls the working layout back.
class OwnerProfilePersonalization extends ConsumerWidget {
  const OwnerProfilePersonalization({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final editing = ref.watch(
      profileCompositionProvider.select((s) => s.editing),
    );

    // Reactive append: while composing, fold every refetch of the owner's widgets
    // into the working layout so a card acquired from ANY channel (a Rank/Main
    // row, the passport row, another sheet, even another device) becomes
    // placeable once the invalidated read actually settles. This depends only on
    // the provider emitting, never on how or when the add sheet closed. The
    // append is idempotent and self-gated on edit + not-saving in the controller.
    // ProfileScreen (which owns this surface) keeps the mutation controller alive,
    // so a write's success-path invalidation reliably drives an emission here.
    ref.listen(ownerProfileWidgetsProvider, (previous, next) {
      if (next case AsyncData(:final value)) {
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
            content: Text(l10n.profileComposeSaveFailed),
          ),
        );
      ref.read(profileCompositionProvider.notifier).acknowledgeSaveFailure();
    });

    return PersonalizationProfileView(
      profile: profile,
      userId: profile.id,
      widgetsProvider: ownerProfileWidgetsProvider,
      rowsBuilder: editing
          ? (context, columnWidth) =>
                CompositionEditorRows(columnWidth: columnWidth)
          : null,
    );
  }
}
