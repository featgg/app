import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/failure.dart';
import '../../../core/l10n/failure_l10n.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../profile/domain/profile.dart';
import 'account_section.dart';
import 'account_section_cancel_controller.dart';
import 'privacy_controller.dart';
import 'settings_current_privacy_provider.dart';
import 'settings_deletion_status_provider.dart';
import 'sign_out_controller.dart';

/// Settings screen: privacy toggle and sign-out, reached from the profile
/// gear action. The profile refreshes its own read whenever this screen is
/// dismissed, so the screen carries no cross-feature refresh signal of its own.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    ref.listen<AsyncValue<void>>(privacyControllerProvider, (previous, next) {
      if (!context.mounted) return;
      if (next.hasError) {
        final error = next.error!;
        final msg = error is Failure
            ? error.localizedMessage(l10n)
            : l10n.errorUnexpected;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              key: const Key('settingsPrivacyErrorSnackBar'),
              content: Text(msg),
            ),
          );
      } else if (next.hasValue && previous?.isLoading == true) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.settingsPrivacyUpdated)));
      }
    });

    ref.listen<AsyncValue<void>>(signOutControllerProvider, (previous, next) {
      if (!context.mounted || !next.hasError) return;
      final error = next.error!;
      final msg = error is Failure
          ? error.localizedMessage(l10n)
          : l10n.errorUnexpected;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    });

    ref.listen<AsyncValue<void>>(accountSectionCancelControllerProvider, (
      previous,
      next,
    ) {
      if (!context.mounted) return;
      if (next.hasError) {
        final error = next.error!;
        final msg = error is Failure
            ? error.localizedMessage(l10n)
            : l10n.errorUnexpected;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              key: const Key('accountCancelErrorSnackBar'),
              content: Text(msg),
            ),
          );
      } else if (next.hasValue && previous?.isLoading == true) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              key: const Key('accountCancelSuccessSnackBar'),
              content: Text(l10n.accountDeletionCancelled),
            ),
          );
      }
    });

    final privacyAsync = ref.watch(settingsCurrentPrivacyProvider);
    final isWriting = ref.watch(privacyControllerProvider).isLoading;
    final isSigningOut = ref.watch(signOutControllerProvider).isLoading;
    // Fail-open: a loading or errored status read leaves the tile enabled, so a
    // transient read never locks the user out of the delete flow.
    final deletionPending = ref
        .watch(settingsDeletionStatusProvider)
        .maybeWhen(data: (s) => s.isPending, orElse: () => false);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: ListView(
          children: [
            const AccountSection(),
            const Divider(height: AppSpacing.xs),
            AsyncValueWidget<ProfilePrivacy>(
              value: privacyAsync,
              onRetry: () => ref.invalidate(settingsCurrentPrivacyProvider),
              data: (privacy) => SwitchListTile.adaptive(
                key: const Key('settingsPrivacyToggle'),
                title: Text(
                  privacy == ProfilePrivacy.private
                      ? l10n.profilePrivacyPrivate
                      : l10n.profilePrivacyPublic,
                ),
                subtitle: Text(l10n.profilePrivacyLabel),
                value: privacy == ProfilePrivacy.private,
                onChanged: isWriting
                    ? null
                    : (isPrivate) {
                        ref
                            .read(privacyControllerProvider.notifier)
                            .setPrivacy(
                              isPrivate
                                  ? ProfilePrivacy.private
                                  : ProfilePrivacy.public,
                            );
                      },
              ),
            ),
            const Divider(height: AppSpacing.xs),
            ListTile(
              key: const Key('settingsSignOutTile'),
              enabled: !isSigningOut,
              leading: const Icon(Icons.logout),
              title: Text(l10n.signOut),
              onTap: () =>
                  ref.read(signOutControllerProvider.notifier).signOut(),
            ),
            const Divider(height: AppSpacing.xs),
            ListTile(
              key: const Key('settingsDeleteAccountTile'),
              enabled: !deletionPending,
              iconColor: Theme.of(context).colorScheme.error,
              textColor: Theme.of(context).colorScheme.error,
              leading: const Icon(Icons.delete_forever),
              title: Text(l10n.settingsDeleteAccount),
              // Settings stays mounted under the pushed delete-account route, so
              // the pending-deletion read is not re-run on return. Invalidate it
              // once the flow pops so a newly-scheduled deletion surfaces the
              // banner without rebuilding the whole screen.
              onTap: () async {
                await context.push('/settings/delete-account');
                if (!context.mounted) return;
                ref.invalidate(settingsDeletionStatusProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}
