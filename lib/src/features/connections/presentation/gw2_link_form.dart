import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../domain/connection.dart';
import 'link_form_controller.dart';

/// Guild Wars 2 link form. Submits `Platform.gw2` with the user's API key
/// via `submitFields({'api_key': ...})`. The key is write-only — it is sent
/// in the link body and never read back or rendered.
class Gw2LinkForm extends ConsumerStatefulWidget {
  const Gw2LinkForm({super.key});

  @override
  ConsumerState<Gw2LinkForm> createState() => _Gw2LinkFormState();
}

class _Gw2LinkFormState extends ConsumerState<Gw2LinkForm> {
  final _controller = TextEditingController();
  bool _obscured = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formState = ref.watch(linkFormControllerProvider(Platform.gw2));
    final notifier = ref.read(
      linkFormControllerProvider(Platform.gw2).notifier,
    );

    ref.listen<LinkFormState>(linkFormControllerProvider(Platform.gw2), (
      prev,
      next,
    ) {
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
          key: const Key('gw2ApiKeyField'),
          controller: _controller,
          // The GW2 API key is a secret credential, not a public username:
          // obscure it by default and keep it out of the keyboard's autocorrect/
          // suggestion/learning store. The suffix toggle lets the user reveal it.
          obscureText: _obscured,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: l10n.connectionsGw2ApiKeyLabel,
            hintText: l10n.connectionsGw2ApiKeyHint,
            errorText: formState.fieldErrors.contains('api_key')
                ? l10n.connectionsGw2ApiKeyRequired
                : null,
            suffixIcon: IconButton(
              key: const Key('gw2ApiKeyVisibilityToggle'),
              icon: Icon(_obscured ? Icons.visibility : Icons.visibility_off),
              tooltip: _obscured
                  ? l10n.connectionsGw2ApiKeyShow
                  : l10n.connectionsGw2ApiKeyHide,
              onPressed: () => setState(() => _obscured = !_obscured),
            ),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(notifier),
        ),
        const SizedBox(height: AppSpacing.md),
        if (formState.failure != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              key: const Key('gw2LinkError'),
              formState.failure!.localizedMessage(l10n),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        FilledButton(
          key: const Key('gw2LinkButton'),
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
    notifier.submitFields({'api_key': _controller.text});
  }
}
