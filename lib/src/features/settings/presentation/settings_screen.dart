import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/l10n/failure_l10n.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../auth/domain/auth_providers.dart';
import '../../profile/domain/profile.dart';
import 'privacy_controller.dart';
import 'settings_current_privacy_provider.dart';

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

    final privacyAsync = ref.watch(settingsCurrentPrivacyProvider);
    final isWriting = ref.watch(privacyControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: ListView(
          children: [
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
              leading: const Icon(Icons.logout),
              title: Text(l10n.signOut),
              onTap: () async {
                final repo = ref.read(authRepositoryProvider);
                final result = await repo.signOut();
                if (!context.mounted) return;
                result.fold((failure) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(content: Text(failure.localizedMessage(l10n))),
                    );
                }, (_) {});
              },
            ),
          ],
        ),
      ),
    );
  }
}
