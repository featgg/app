import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import 'account_identity_provider.dart';
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
    final identity = ref.watch(accountIdentityProvider);
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
          deletionAsync.when(
            // Both skip flags are passed explicitly so a re-read keeps whatever
            // is already on screen instead of blinking through an empty slot.
            skipLoadingOnReload: true,
            skipLoadingOnRefresh: true,
            data: (status) => status.isPending && status.scheduledAt != null
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: _DeletionBanner(scheduledAt: status.scheduledAt!),
                  )
                : const SizedBox.shrink(),
            // A failed read must not render as an empty slot: that is exactly
            // how "no deletion pending" looks, so a user inside the grace
            // period would be told the opposite of the truth.
            error: (_, _) => Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: _DeletionStatusUnavailable(
                isRetrying: deletionAsync.isLoading,
                onRetry: () => ref.invalidate(settingsDeletionStatusProvider),
              ),
            ),
            // Silent on purpose: the slot is empty for almost every account, so
            // a placeholder here would promise something is arriving for
            // everyone and flash on every cold start.
            loading: () => const SizedBox.shrink(),
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

/// Shown in the deletion slot when the status read failed. It asserts nothing
/// about whether a deletion is pending — the app genuinely does not know — so
/// it stays on the neutral surface role rather than the error colouring the
/// pending banner owns, and carries the re-read itself: without it the only way
/// back to the countdown and its Cancel button would be leaving the screen.
class _DeletionStatusUnavailable extends StatelessWidget {
  const _DeletionStatusUnavailable({
    required this.isRetrying,
    required this.onRetry,
  });

  /// True while the re-read is in flight, which disables the action so mashing
  /// it cannot fan out concurrent privileged reads.
  final bool isRetrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      key: const Key('accountDeletionStatusUnavailable'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.accountDeletionStatusUnavailableTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.accountDeletionStatusUnavailableBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            key: const Key('accountDeletionStatusRetryButton'),
            onPressed: isRetrying ? null : onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.asyncRetry),
          ),
        ],
      ),
    );
  }
}
