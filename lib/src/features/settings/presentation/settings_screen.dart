import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/failure.dart';
import '../../../core/l10n/failure_l10n.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../connections/domain/connection.dart';
import '../../connections/domain/platform_descriptor.dart';
import '../../profile/domain/profile.dart';
import 'account_section.dart';
import 'account_section_cancel_controller.dart';
import 'feed_preview_controller.dart';
import 'privacy_controller.dart';
import 'settings_current_privacy_provider.dart';
import 'settings_deletion_status_provider.dart';
import 'settings_feed_preview_provider.dart';
import 'sign_out_controller.dart';

/// A made choice, so "the owner picked Automatic" (a null platform) stays
/// distinguishable from "the owner dismissed the sheet" (no choice at all).
class _FeedPreviewChoice {
  const _FeedPreviewChoice(this.value);

  final Platform? value;
}

/// Offers Automatic plus every platform the owner can pin, and resolves to the
/// tapped option — or null when the sheet is dismissed. Plain tiles with a
/// check on the current choice rather than radios: every row must close the
/// sheet, including the one already selected, and a radio ignores that tap.
Future<_FeedPreviewChoice?> _pickFeedPreview(
  BuildContext context,
  AppLocalizations l10n,
  FeedPreviewOptions options,
) => showModalBottomSheet<_FeedPreviewChoice>(
  context: context,
  builder: (sheetContext) {
    Widget option(Key key, String label, Platform? value) => ListTile(
      key: key,
      title: Text(label),
      trailing: value == options.selected ? const Icon(Icons.check) : null,
      onTap: () => Navigator.of(sheetContext).pop(_FeedPreviewChoice(value)),
    );

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          option(
            const Key('feedPreviewOption_default'),
            l10n.profileFeaturedCardDefault,
            null,
          ),
          for (final platform in options.selectable)
            option(
              Key('feedPreviewOption_${platform.name}'),
              platformDescriptors[platform]?.displayName ?? platform.name,
              platform,
            ),
        ],
      ),
    );
  },
);

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

    ref.listen<AsyncValue<void>>(feedPreviewControllerProvider, (
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
            key: const Key('settingsFeedPreviewErrorSnackBar'),
            content: Text(msg),
          ),
        );
    });

    final privacyAsync = ref.watch(settingsCurrentPrivacyProvider);
    final feedPreviewAsync = ref.watch(settingsFeedPreviewProvider);
    final isWriting = ref.watch(privacyControllerProvider).isLoading;
    final isWritingFeedPreview = ref
        .watch(feedPreviewControllerProvider)
        .isLoading;
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
            // The feed preview lives here, not on the profile: it decides how
            // the profile reads in discovery, which is the one surface the
            // owner cannot see from their own page.
            AsyncValueWidget<FeedPreviewOptions>(
              value: feedPreviewAsync,
              onRetry: () => ref.invalidate(settingsFeedPreviewProvider),
              data: (options) => ListTile(
                key: const Key('settingsFeedPreviewTile'),
                enabled: !isWritingFeedPreview,
                title: Text(
                  options.selected == null
                      ? l10n.profileFeaturedCardDefault
                      : platformDescriptors[options.selected]?.displayName ??
                            options.selected!.name,
                ),
                subtitle: Text(l10n.settingsFeedPreviewLabel),
                onTap: () async {
                  final picked = await _pickFeedPreview(context, l10n, options);
                  // A dismissed sheet yields no choice; re-picking the current
                  // value is not an edit and costs no write.
                  if (picked == null || picked.value == options.selected) {
                    return;
                  }
                  await ref
                      .read(feedPreviewControllerProvider.notifier)
                      .setFeaturedPlatform(picked.value);
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
