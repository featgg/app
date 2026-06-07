import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../domain/connection.dart';
import 'link_form_controller.dart';

/// League of Legends link form. Collects `game_name`, `tag_line`, and `region`
/// as metadata fields. The widget owns all three [TextEditingController]s so
/// typed values are never cleared on a backend failure.
class LeagueOfLegendsLinkForm extends ConsumerStatefulWidget {
  const LeagueOfLegendsLinkForm({super.key});

  @override
  ConsumerState<LeagueOfLegendsLinkForm> createState() =>
      _LeagueOfLegendsLinkFormState();
}

class _LeagueOfLegendsLinkFormState
    extends ConsumerState<LeagueOfLegendsLinkForm> {
  final _gameNameCtrl = TextEditingController();
  final _tagLineCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();

  @override
  void dispose() {
    _gameNameCtrl.dispose();
    _tagLineCtrl.dispose();
    _regionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final platform = Platform.leagueOfLegends;
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
      _gameNameCtrl.clear();
      _tagLineCtrl.clear();
      _regionCtrl.clear();
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('lolGameNameField'),
          controller: _gameNameCtrl,
          decoration: InputDecoration(
            labelText: l10n.connectionsLolGameNameLabel,
            hintText: l10n.connectionsLolGameNameHint,
            errorText: formState.fieldErrors.contains('game_name')
                ? l10n.connectionsLolGameNameRequired
                : null,
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const Key('lolTagLineField'),
          controller: _tagLineCtrl,
          decoration: InputDecoration(
            labelText: l10n.connectionsLolTagLineLabel,
            hintText: l10n.connectionsLolTagLineHint,
            errorText: formState.fieldErrors.contains('tag_line')
                ? l10n.connectionsLolTagLineRequired
                : null,
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const Key('lolRegionField'),
          controller: _regionCtrl,
          decoration: InputDecoration(
            labelText: l10n.connectionsLolRegionLabel,
            hintText: l10n.connectionsLolRegionHint,
            errorText: formState.fieldErrors.contains('region')
                ? l10n.connectionsLolRegionRequired
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
              key: const Key('lolLinkError'),
              formState.failure!.localizedMessage(l10n),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        FilledButton(
          key: const Key('lolLinkButton'),
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
      'game_name': _gameNameCtrl.text,
      'tag_line': _tagLineCtrl.text,
      'region': _regionCtrl.text,
    });
  }
}
