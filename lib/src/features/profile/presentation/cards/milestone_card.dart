import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/core.dart';
import '../../../connections/domain/game_card.dart';
import '../../domain/profile_archetype.dart';
import '../../domain/profile_widget.dart';
import '../../domain/showcase_value_resolver.dart';
import '../art_framing_control.dart';
import '../personalization_card_shell.dart';
import '../profile_owner_cards_provider.dart';
import 'card_data.dart';
import 'card_key.dart';

/// Milestone archetype, which the Showcase card evolves into: the showcased
/// game's cover fills the card with its progress in the datum. Resolves the game
/// through the pure [resolveShowcase]; a game with no cover — or none resolved —
/// degrades to the archetype's motif with whatever the datum still names.
class MilestoneCard extends ConsumerWidget {
  const MilestoneCard({
    super.key,
    required this.widget,
    required this.size,
    this.cardSource,
  });

  final ProfileWidget widget;
  final ProfileCardSize size;
  final CardSource? cardSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final platform = widget.platform;
    final card = platform == null
        ? null
        : resolveCard(ref, cardSource, platform);
    final data = card?.data;
    final resolved = resolveShowcase(
      data is SteamCardData ? data : null,
      widget.showcaseSelection,
    );

    return PersonalizationCardShell(
      key: personalizationCardKey(widget.id),
      archetype: ProfileArchetype.milestone,
      size: size,
      art: resolved?.heroImage,
      framing: ArtFramingTarget(widgetId: widget.id, framing: widget.framing),
      subject: resolved?.title,
      stats: milestoneStats(resolved, l10n),
    );
  }
}
