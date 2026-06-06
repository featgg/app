import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../domain/connection.dart';
import 'link_form_controller.dart';

/// Steam-specific link form. Owns the [TextEditingController] so the typed
/// value is never cleared on a backend failure — only the controller's state
/// (error flags) is updated.
class SteamLinkForm extends ConsumerStatefulWidget {
  const SteamLinkForm({super.key});

  @override
  ConsumerState<SteamLinkForm> createState() => _SteamLinkFormState();
}

class _SteamLinkFormState extends ConsumerState<SteamLinkForm> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formState = ref.watch(linkFormControllerProvider);
    final notifier = ref.read(linkFormControllerProvider.notifier);

    // Show a snackbar once linking succeeds, then reset the form.
    ref.listen<LinkFormState>(linkFormControllerProvider, (prev, next) {
      if (!next.linked || (prev?.linked == true)) return;
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.connectionsLinked)));
      _controller.clear();
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('steamRemoteIdField'),
          controller: _controller,
          decoration: InputDecoration(
            labelText: l10n.connectionsSteamRemoteIdLabel,
            hintText: l10n.connectionsSteamRemoteIdHint,
            errorText: formState.remoteIdError
                ? l10n.connectionsRemoteIdRequired
                : null,
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(notifier),
        ),
        const SizedBox(height: AppSpacing.md),
        if (formState.failure != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              key: const Key('steamLinkError'),
              formState.failure!.localizedMessage(l10n),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        FilledButton(
          key: const Key('steamLinkButton'),
          onPressed: formState.submitting ? null : () => _submit(notifier),
          child: formState.submitting
              ? const SizedBox(
                  width: AppSpacing.md,
                  height: AppSpacing.md,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                )
              : Text(l10n.connectionsLink),
        ),
      ],
    );
  }

  void _submit(LinkFormController notifier) {
    notifier.submit(platform: Platform.steam, remoteId: _controller.text);
  }
}
