import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/core.dart';
import '../../../connections/domain/connection.dart';
import '../../../connections/domain/game_card.dart';
import '../../../connections/domain/platform_descriptor.dart';
import '../../domain/passport_value_resolver.dart';
import '../../domain/profile_archetype.dart';
import '../../domain/profile_widget.dart';
import '../../domain/showcase_value_resolver.dart';
import '../personalization_card_shell.dart';
import '../profile_owner_cards_provider.dart';
import 'card_data.dart';
import 'card_key.dart';

/// Identity archetype (spec §7, evolves the Passport card): cross-platform
/// *membership* — a chip per linked platform plus the linked-platform count.
/// Full only. Folds every platform's card through the pure [resolvePassport];
/// an errored or still-loading platform reads as absent and never errors the
/// card (spec: unresolved content → neutral, never an error tile).
class IdentityCard extends ConsumerWidget {
  const IdentityCard({
    super.key,
    required this.widget,
    this.cardSource,
    this.memberSince,
  });

  final ProfileWidget widget;
  final CardSource? cardSource;

  /// Profile creation date backing the member-since stat; omitted from the
  /// datum when null (never fabricated).
  final DateTime? memberSince;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = PersonalizationTheme.of(context);

    final cards = <Platform, GameCard?>{
      for (final platform in Platform.values)
        platform: resolveCard(ref, cardSource, platform),
    };
    final entries = resolvePassport(cards)?.entries ?? const <PassportEntry>[];

    return PersonalizationCardShell(
      key: personalizationCardKey(widget.id),
      archetype: ProfileArchetype.identity,
      size: ProfileCardSize.full,
      framedContent: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final entry in entries)
            _IdentityChip(
              widgetId: widget.id,
              platform: entry.platform,
              palette: palette,
            ),
        ],
      ),
      stats: [
        PersonalizationStat(
          value: formatShowcaseHeroValue(entries.length),
          label: l10n.personalizationStatPlatforms,
        ),
        if (memberSince case final since?)
          PersonalizationStat(
            value: since.year.toString(),
            label: l10n.personalizationStatMemberSince,
          ),
      ],
    );
  }
}

class _IdentityChip extends StatelessWidget {
  const _IdentityChip({
    required this.widgetId,
    required this.platform,
    required this.palette,
  });

  final String widgetId;
  final Platform platform;
  final PersonalizationPalette palette;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Brand-correct platform name (proper noun, intentionally not localized) —
    // text only, never a logo or brand color.
    final name = platformDescriptors[platform]?.displayName ?? platform.name;

    return Container(
      key: Key('personalizationIdentityChip_${widgetId}_${platform.name}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smMd,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: palette.accentSoft,
        border: Border.all(
          color: palette.accent,
          width: PersonalizationLayout.borderWidth,
        ),
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Text(
        name,
        style: textTheme.labelMedium?.copyWith(
          color: palette.text,
          fontWeight: AppTypography.semiBold,
        ),
      ),
    );
  }
}
