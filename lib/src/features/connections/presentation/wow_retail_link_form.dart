import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../domain/connection.dart';
import 'link_form_controller.dart';

/// WoW (Retail) link form. Collects `region`, `realm`, and `character` as
/// metadata fields. The widget owns all three [TextEditingController]s so
/// typed values are never cleared on a backend failure.
class WowRetailLinkForm extends ConsumerStatefulWidget {
  const WowRetailLinkForm({super.key});

  @override
  ConsumerState<WowRetailLinkForm> createState() => _WowRetailLinkFormState();
}

class _WowRetailLinkFormState extends ConsumerState<WowRetailLinkForm> {
  final _regionCtrl = TextEditingController();
  final _realmCtrl = TextEditingController();
  final _characterCtrl = TextEditingController();

  @override
  void dispose() {
    _regionCtrl.dispose();
    _realmCtrl.dispose();
    _characterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const platform = Platform.wowRetail;
    final formState = ref.watch(linkFormControllerProvider(platform));
    final notifier = ref.read(linkFormControllerProvider(platform).notifier);

    ref.listen<LinkFormState>(linkFormControllerProvider(platform), (
      prev,
      next,
    ) {
      if (!next.linked || (prev?.linked == true)) return;
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.connectionsLinked)));
      _regionCtrl.clear();
      _realmCtrl.clear();
      _characterCtrl.clear();
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('wowRegionField'),
          controller: _regionCtrl,
          decoration: InputDecoration(
            labelText: l10n.connectionsWowRegionLabel,
            hintText: l10n.connectionsWowRegionHint,
            errorText: formState.fieldErrors.contains('region')
                ? l10n.connectionsWowRegionRequired
                : null,
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const Key('wowRealmField'),
          controller: _realmCtrl,
          decoration: InputDecoration(
            labelText: l10n.connectionsWowRealmLabel,
            hintText: l10n.connectionsWowRealmHint,
            errorText: formState.fieldErrors.contains('realm')
                ? l10n.connectionsWowRealmRequired
                : null,
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const Key('wowCharacterField'),
          controller: _characterCtrl,
          decoration: InputDecoration(
            labelText: l10n.connectionsWowCharacterLabel,
            hintText: l10n.connectionsWowCharacterHint,
            errorText: formState.fieldErrors.contains('character')
                ? l10n.connectionsWowCharacterRequired
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
              key: const Key('wowLinkError'),
              formState.failure!.localizedMessage(l10n),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        FilledButton(
          key: const Key('wowLinkButton'),
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
    notifier.submitFields({
      'region': _regionCtrl.text,
      'realm': _realmCtrl.text,
      'character': _characterCtrl.text,
    });
  }
}
