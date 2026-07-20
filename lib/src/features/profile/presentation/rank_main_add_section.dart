import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../connections/domain/connection.dart';
import '../../connections/domain/game_card.dart';
import '../../connections/domain/platform_descriptor.dart';
import '../domain/main_value_resolver.dart';
import '../domain/profile_widget.dart';
import '../domain/rank_value_resolver.dart';
import 'profile_owner_cards_provider.dart';
import 'profile_widgets_controller.dart';

/// A dedicated add-entry for the Rank and Main cards, rendered in the add-card
/// sheet OUTSIDE the Steam-card gate. Each card is platform-bound; a row is
/// offered only for a supported platform whose owner card actually carries the
/// data (resolver non-null) and that is not already placed. When nothing
/// qualifies the section collapses to nothing, so it is zero-impact on the sheet.
class RankMainAddSection extends ConsumerWidget {
  const RankMainAddSection({super.key, required this.existing});

  final List<ProfileWidget> existing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // Append after the current max position to avoid a foreseeable unique
    // collision; the backend constraint stays authoritative.
    final nextPosition = existing.isEmpty
        ? 0
        : existing.map((w) => w.position).reduce((a, b) => a > b ? a : b) + 1;

    final rows = <Widget>[
      for (final platform in kRankPlatforms)
        if (_offers(ref, ProfileWidgetKind.rank, platform, resolveRank))
          _AddRow(
            rowKey: Key('rankAddRow_${platform.name}'),
            label: _brand(platform),
            kindLabel: l10n.personalizationRankTitle,
            textTheme: textTheme,
            onTap: () {
              ref
                  .read(profileWidgetsControllerProvider.notifier)
                  .addRank(
                    platform: platform,
                    position: nextPosition,
                    size: ProfileWidgetSize.small,
                  );
              Navigator.of(context).pop();
            },
          ),
      for (final platform in kMainPlatforms)
        if (_offers(ref, ProfileWidgetKind.main, platform, resolveMain))
          _AddRow(
            rowKey: Key('mainAddRow_${platform.name}'),
            label: _brand(platform),
            kindLabel: l10n.personalizationMainTitle,
            textTheme: textTheme,
            onTap: () {
              ref
                  .read(profileWidgetsControllerProvider.notifier)
                  .addMain(
                    platform: platform,
                    position: nextPosition,
                    size: ProfileWidgetSize.small,
                  );
              Navigator.of(context).pop();
            },
          ),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Container(
        key: const Key('rankMainAddSection'),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.rankMainAddTitle, style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            ...rows,
          ],
        ),
      ),
    );
  }

  /// Whether a [kind] card for [platform] should be offered: the owner card bound
  /// to that platform is present, the [resolve] resolver finds renderable data,
  /// and no widget of the same (kind, platform) is already placed.
  bool _offers(
    WidgetRef ref,
    ProfileWidgetKind kind,
    Platform platform,
    Object? Function(GameCard?) resolve,
  ) {
    if (existing.any((w) => w.kind == kind && w.platform == platform)) {
      return false;
    }
    final state = ref.watch(ownerCardProvider(platform));
    final card = state.hasError ? null : state.value;
    // The offered card must be the one bound to this platform (holds in
    // production; a cross-wired fixture card would otherwise resolve falsely).
    if (card == null || card.platform != platform) return false;
    return resolve(card) != null;
  }

  /// Brand-correct platform name (proper noun, intentionally not localized).
  String _brand(Platform platform) =>
      platformDescriptors[platform]?.displayName ?? platform.name;
}

/// One tappable acquisition row: the brand name with the card-kind tag.
class _AddRow extends StatelessWidget {
  const _AddRow({
    required this.rowKey,
    required this.label,
    required this.kindLabel,
    required this.textTheme,
    required this.onTap,
  });

  final Key rowKey;
  final String label;
  final String kindLabel;
  final TextTheme textTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      key: rowKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.smMd,
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: textTheme.bodyMedium)),
            Text(
              kindLabel,
              style: textTheme.labelSmall?.copyWith(color: colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
