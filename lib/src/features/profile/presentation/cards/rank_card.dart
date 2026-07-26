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

    // This card is always framed, so nothing but its label says which platform
    // the rank belongs to — and the label belongs to the hero, which is the
    // number the card answers with. The stats beside it explain that number and
    // inherit the platform from it.
    final shortName = cardLabelPlatform(platform, hasArt: false);
    final stats = statsFromResolved(
      resolved?.stats ?? const [],
      l10n,
      PersonalizationLayout.statCapFull,
    );
    // What this card answers with depends on the platform: a tier where one is
    // published, the rating itself where none is. Either way the scope — a
    // Chess mode, a queue — is what makes the answer mean something, so it is
    // the hero's label rather than a line of its own. No static label can carry
    // it: it comes from the payload, and where the payload has none the
    // platform's own name does the naming.
    final tier = resolved?.heading;
    final scope = resolved?.scope;
    final fallbackLabel = shortName == null
        ? l10n.personalizationStatRank
        : '$shortName ${l10n.personalizationStatRank}';
    final PersonalizationStat? hero;
    final List<PersonalizationStat> supporting;
    if (tier != null) {
      hero = PersonalizationStat(value: tier, label: scope ?? fallbackLabel);
      supporting = stats;
    } else if (stats.isNotEmpty) {
      hero = PersonalizationStat(
        value: stats.first.value,
        label: scope ?? fallbackLabel,
      );
      supporting = stats.skip(1).toList();
    } else {
      hero = null;
      supporting = const [];
    }

    return PersonalizationCardShell(
      key: personalizationCardKey(widget.id),
      archetype: ProfileArchetype.rank,
      size: size,
      hero: hero,
      stats: supporting,
    );
  }
}
