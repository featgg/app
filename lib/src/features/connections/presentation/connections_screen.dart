import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../domain/connection.dart';
import '../domain/platform_descriptor.dart';
import 'connection_actions_controller.dart';
import 'connections_provider.dart';
import 'game_card_widget.dart';
import 'steam_link_form.dart';

class ConnectionsScreen extends ConsumerWidget {
  const ConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final connectionsState = ref.watch(myConnectionsProvider);

    // Show snackbars for refresh / unlink outcomes.
    ref.listen<ConnectionActionsState>(connectionActionsControllerProvider, (
      prev,
      next,
    ) {
      if (!context.mounted) return;
      if (next.unlinked && !(prev?.unlinked ?? false)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.connectionsUnlinked)));
      } else if (!next.refreshing &&
          (prev?.refreshing ?? false) &&
          next.failure == null &&
          !next.refreshSkipped) {
        // Refresh succeeded with fresh data — no explicit snackbar needed;
        // the card re-renders from the invalidated provider.
      } else if (next.refreshSkipped && !(prev?.refreshSkipped ?? false)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.connectionsRefreshSkipped)));
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.connectionsTitle)),
      body: AsyncValueWidget<List<Connection>>(
        value: connectionsState,
        onRetry: () => ref.invalidate(myConnectionsProvider),
        data: (connections) => _ConnectionsBody(connections: connections),
      ),
    );
  }
}

class _ConnectionsBody extends ConsumerWidget {
  const _ConnectionsBody({required this.connections});

  final List<Connection> connections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final visible = connections
        .where((c) => platformDescriptors.containsKey(c.platform))
        .toList();
    final hasSteam = visible.any((c) => c.platform == Platform.steam);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                key: const Key('connectionsEmpty'),
                l10n.connectionsEmpty,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ...visible.map(
            (c) => Padding(
              key: Key('connection_${c.platform.name}'),
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _ConnectionTile(connection: c),
            ),
          ),
          if (hasSteam) ...[
            const SizedBox(height: AppSpacing.sm),
            const GameCardWidget(key: Key('steamCardWidget')),
            const SizedBox(height: AppSpacing.md),
          ],
          if (!hasSteam) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.connectionsAddSteam,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            const SteamLinkForm(),
          ],
        ],
      ),
    );
  }
}

class _ConnectionTile extends ConsumerWidget {
  const _ConnectionTile({required this.connection});

  final Connection connection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final actionsState = ref.watch(connectionActionsControllerProvider);
    final actionsNotifier = ref.read(
      connectionActionsControllerProvider.notifier,
    );
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final isRefreshing = actionsState.refreshing;
    final isUnlinking = actionsState.unlinking;
    final onCooldown = actionsState.onCooldown;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        platformDescriptors[connection.platform]?.displayName ??
                            connection.platform.name,
                        style: textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(
                            connection.status == ConnectionStatus.active
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                            size: AppSpacing.md,
                            color: connection.status == ConnectionStatus.active
                                ? colorScheme.primary
                                : colorScheme.error,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            connection.status == ConnectionStatus.active
                                ? l10n.connectionsStatusActive
                                : l10n.connectionsStatusError,
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        connection.lastSyncAt != null
                            ? l10n.connectionsLastSync(
                                MaterialLocalizations.of(
                                  context,
                                ).formatMediumDate(
                                  connection.lastSyncAt!.toLocal(),
                                ),
                              )
                            : l10n.connectionsLastSyncNever,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      key: Key('refreshButton_${connection.platform.name}'),
                      icon: isRefreshing
                          ? const SizedBox(
                              width: AppSpacing.md,
                              height: AppSpacing.md,
                              child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.refresh),
                      tooltip: l10n.connectionsRefresh,
                      onPressed: (isRefreshing || onCooldown)
                          ? null
                          : () => actionsNotifier.refresh(connection.platform),
                    ),
                    IconButton(
                      key: Key('unlinkButton_${connection.platform.name}'),
                      icon: isUnlinking
                          ? const SizedBox(
                              width: AppSpacing.md,
                              height: AppSpacing.md,
                              child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.link_off),
                      tooltip: l10n.connectionsUnlink,
                      onPressed: isUnlinking
                          ? null
                          : () => actionsNotifier.unlink(connection.platform),
                    ),
                  ],
                ),
              ],
            ),
            if (onCooldown)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  key: const Key('cooldownHint'),
                  l10n.connectionsRefreshCooldown,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (actionsState.failure != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  key: const Key('actionsError'),
                  actionsState.failure!.localizedMessage(l10n),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
