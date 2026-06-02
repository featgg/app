import 'package:featgg/src/core/core.dart';
import 'package:featgg/src/features/auth/domain/auth_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Root screen of the app, reached through the central router at '/'.
///
/// Temporary sign-out action is present until a settings surface exists.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'Feat.gg',
            style: textTheme.displayLarge?.copyWith(color: colorScheme.primary),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final repo = ref.read(authRepositoryProvider);
          final result = await repo.signOut();
          result.fold((failure) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(failure.localizedMessage(l10n))),
            );
          }, (_) {});
        },
        label: Text(l10n.signOut),
        icon: const Icon(Icons.logout),
      ),
    );
  }
}
