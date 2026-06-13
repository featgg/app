import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../auth/domain/auth_domain.dart';
import 'account_section_cancel_controller.dart';
import 'settings_deletion_status_provider.dart';

/// Account section of the settings screen: the signed-in identity (email +
/// provider when present) and, when a deletion is pending, a grace-period
/// banner with a live countdown to the 7-day target and a Cancel button.
class AccountSection extends ConsumerWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Synchronous in-memory read of the restored session, mirroring the
    // main.dart precedent of reading currentStatus() off the repository.
    final identity = ref.read(authRepositoryProvider).currentIdentity();
    final deletionAsync = ref.watch(settingsDeletionStatusProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.settingsAccountSection, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          if (identity?.email != null) ...[
            _IdentityRow(
              key: const Key('accountSectionIdentityEmail'),
              label: l10n.accountEmailLabel,
              value: identity!.email!,
            ),
          ],
          if (_providerLabel(l10n, identity?.providerToken) case final p?) ...[
            const SizedBox(height: AppSpacing.xs),
            _IdentityRow(
              key: const Key('accountSectionIdentityProvider'),
              label: l10n.accountProviderLabel,
              value: p,
            ),
          ],
          deletionAsync.maybeWhen(
            data: (status) => status.isPending && status.scheduledAt != null
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: _DeletionBanner(scheduledAt: status.scheduledAt!),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// Maps a known provider token to its localized label, or null to omit the
  /// provider line for an absent/unrecognized token.
  String? _providerLabel(AppLocalizations l10n, String? token) =>
      switch (token) {
        'email' => l10n.accountProviderEmail,
        'google' => l10n.accountProviderGoogle,
        'discord' => l10n.accountProviderDiscord,
        _ => null,
      };
}

class _IdentityRow extends StatelessWidget {
  const _IdentityRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

class _DeletionBanner extends ConsumerWidget {
  const _DeletionBanner({required this.scheduledAt});

  final DateTime scheduledAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isCancelling = ref
        .watch(accountSectionCancelControllerProvider)
        .isLoading;

    return Container(
      key: const Key('accountDeletionBanner'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.accountDeletionPendingTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.accountDeletionPendingBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          CooldownCountdown(
            until: scheduledAt,
            label: (seconds) =>
                l10n.accountDeletionCountdown(_daysFromSeconds(seconds)),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('accountCancelDeletionButton'),
            onPressed: isCancelling
                ? null
                : () => ref
                      .read(accountSectionCancelControllerProvider.notifier)
                      .cancel(),
            child: Text(l10n.accountCancelDeletionButton),
          ),
        ],
      ),
    );
  }

  /// Whole days remaining, rounding up so a partial final day still reads as a
  /// day left rather than dropping to zero before the deadline.
  int _daysFromSeconds(int seconds) =>
      (seconds / Duration.secondsPerDay).ceil();
}
