import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../core/error/failure.dart';
import '../domain/connection.dart';
import '../domain/platform_descriptor.dart';
import 'chess_link_form.dart';
import 'connection_actions_controller.dart';
import 'gw2_link_form.dart';
import 'connections_provider.dart';
import 'league_of_legends_link_form.dart';
import 'minecraft_link_form.dart';
import 'retroachievements_link_form.dart';
import 'steam_link_form.dart';
import 'wow_retail_link_form.dart';

/// Presentation-side registry mapping each registered [Platform] to its
/// link-form builder. Lives here (its only consumer) so the screen can select
/// a form without a switch. A later platform adds one entry here alongside its
/// descriptor, card-parser, and card-view registry entries.
const Map<Platform, Widget Function({Key? key})> _linkFormRegistry = {
  Platform.steam: SteamLinkForm.new,
  Platform.minecraftHypixel: MinecraftLinkForm.new,
  Platform.retroachievements: RetroAchievementsLinkForm.new,
  Platform.leagueOfLegends: LeagueOfLegendsLinkForm.new,
  Platform.wowRetail: WowRetailLinkForm.new,
  Platform.chess: ChessLinkForm.new,
  Platform.gw2: Gw2LinkForm.new,
};

class ConnectionsScreen extends ConsumerWidget {
  const ConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final connectionsState = ref.watch(myConnectionsProvider);

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
    final connectedPlatforms = {for (final c in visible) c.platform};

    // Per-platform snackbars for refresh / unlink outcomes. Registered against
    // the stable descriptor set (not the async visible list) so the listener
    // count is fixed per build. Lives here rather than in _ConnectionTile so
    // the unlink snackbar fires even after the tile unmounts.
    for (final platform in platformDescriptors.keys) {
      ref.listen<ConnectionActionsState>(
        connectionActionsControllerProvider(platform),
        (prev, next) {
          if (!context.mounted) return;
          if (next.unlinked && !(prev?.unlinked ?? false)) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.connectionsUnlinked)));
          } else if (next.refreshSkipped && !(prev?.refreshSkipped ?? false)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.connectionsRefreshSkipped)),
            );
          }
        },
      );
    }

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
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
            for (final c in visible)
              Padding(
                key: Key('connection_${c.platform.name}'),
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _ConnectionTile(connection: c),
              ),
            for (final descriptor in platformDescriptors.values)
              if (!connectedPlatforms.contains(descriptor.platform)) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.connectionsConnectPlatform(descriptor.displayName),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                _linkFormRegistry[descriptor.platform]!(
                  key: Key('linkForm_${descriptor.platform.name}'),
                ),
              ],
          ],
        ),
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
    final actionsState = ref.watch(
      connectionActionsControllerProvider(connection.platform),
    );
    final actionsNotifier = ref.read(
      connectionActionsControllerProvider(connection.platform).notifier,
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
                          : () => actionsNotifier.refresh(),
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
                          : () => actionsNotifier.unlink(),
                    ),
                  ],
                ),
              ],
            ),
            if (onCooldown && actionsState.cooldownUntil != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: CooldownCountdown(
                  key: const Key('cooldownHint'),
                  until: actionsState.cooldownUntil!,
                  label: (s) => l10n.connectionsRefreshCooldownCountdown(s),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            // A cooldown is already conveyed by the countdown above; suppress
            // its redundant error text. Other failures still surface here.
            if (actionsState.failure != null &&
                actionsState.failure is! SyncCooldownFailure)
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
