import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/core.dart';
import '../../domain/profile_archetype.dart';
import '../../domain/profile_widget.dart';
import '../../domain/rank_value_resolver.dart';
import '../personalization_card_shell.dart';
import '../profile_owner_cards_provider.dart';
import 'card_data.dart';
import 'card_key.dart';

/// Rank archetype (spec §7): "how good am I" — no platform publishes rank-crest
/// art, so the card always renders framed over its crest motif, with the tier
/// line and headline numbers in the datum. Folds the bound platform's card
/// through the pure [resolveRank]; a payload with no rank/rating renders a
/// neutral no-data crest, never a fallback.
class RankCard extends ConsumerWidget {
  const RankCard({
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
    final resolved = resolveRank(card);

    final isFull = size == ProfileCardSize.full;
    return PersonalizationCardShell(
      key: personalizationCardKey(widget.id),
      archetype: ProfileArchetype.rank,
      size: size,
      subject: resolved?.heading,
      detail: resolved?.scope,
      stats: statsFromResolved(
        resolved?.stats ?? const [],
        l10n,
        isFull
            ? PersonalizationLayout.statCapFull
            : PersonalizationLayout.statCapHalf,
      ),
    );
  }
}
