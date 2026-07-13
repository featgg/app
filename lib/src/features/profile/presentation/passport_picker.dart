import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../domain/profile_widget.dart';
import 'profile_widgets_controller.dart';

/// A dedicated add-entry for the passport card, rendered above the add-card
/// sheet's mode toggle and OUTSIDE the Steam-card gate — the passport aggregates
/// every linked platform, so a Steam-less user must still be able to add it.
///
/// The passport is a client singleton (one per profile), so once one is present
/// the banner shows an already-added notice instead of the Add action (the
/// collector/completionist precedent). Adding inserts a `wide` passport at the
/// next position (max+1, the same rule the other adds use) through the
/// host-observed controller and closes the sheet.
class PassportAddBanner extends ConsumerWidget {
  const PassportAddBanner({super.key, required this.existing});

  final List<ProfileWidget> existing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final alreadyAdded = existing.any(
      (w) => w.kind == ProfileWidgetKind.passport,
    );
    // Append after the current max position to avoid a foreseeable unique
    // collision; the backend constraint stays authoritative.
    final nextPosition = existing.isEmpty
        ? 0
        : existing.map((w) => w.position).reduce((a, b) => a > b ? a : b) + 1;

    return Container(
      key: const Key('passportBanner'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.passportPickerTitle,
            key: const Key('passportPickerTitle'),
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (alreadyAdded)
            Text(
              l10n.passportPickerAlreadyAdded,
              key: const Key('passportPickerAllAdded'),
              style: textTheme.bodyMedium,
            )
          else ...[
            Text(l10n.passportPickerHint, style: textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('passportPickerAddButton'),
              onPressed: () {
                ref
                    .read(profileWidgetsControllerProvider.notifier)
                    .addPassport(
                      position: nextPosition,
                      size: ProfileWidgetSize.wide,
                    );
                Navigator.of(context).pop();
              },
              child: Text(l10n.passportPickerAdd),
            ),
          ],
        ],
      ),
    );
  }
}
