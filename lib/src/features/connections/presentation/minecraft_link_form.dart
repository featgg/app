import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../domain/connection.dart';
import 'link_form_controller.dart';

/// Minecraft (Hypixel) link form. Submits `Platform.minecraftHypixel` with
/// the user's Minecraft username as `remote_id`.
class MinecraftLinkForm extends ConsumerStatefulWidget {
  const MinecraftLinkForm({super.key});

  @override
  ConsumerState<MinecraftLinkForm> createState() => _MinecraftLinkFormState();
}

class _MinecraftLinkFormState extends ConsumerState<MinecraftLinkForm> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formState = ref.watch(
      linkFormControllerProvider(Platform.minecraftHypixel),
    );
    final notifier = ref.read(
      linkFormControllerProvider(Platform.minecraftHypixel).notifier,
    );

    ref.listen<LinkFormState>(
      linkFormControllerProvider(Platform.minecraftHypixel),
      (prev, next) {
        if (!next.linked || (prev?.linked == true)) return;
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.connectionsLinked)));
        _controller.clear();
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('minecraftRemoteIdField'),
          controller: _controller,
          decoration: InputDecoration(
            labelText: l10n.connectionsMinecraftRemoteIdLabel,
            hintText: l10n.connectionsMinecraftRemoteIdHint,
            errorText: formState.remoteIdError
                ? l10n.connectionsMinecraftRemoteIdRequired
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
              key: const Key('minecraftLinkError'),
              formState.failure!.localizedMessage(l10n),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        FilledButton(
          key: const Key('minecraftLinkButton'),
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
    notifier.submit(remoteId: _controller.text);
  }
}
