import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/core.dart';
import '../../domain/profile_archetype.dart';
import '../../domain/profile_widget.dart';
import '../personalization_card_shell.dart';
import '../profile_owner_cards_provider.dart';
import 'card_data.dart';
import 'card_key.dart';

/// Platform archetype: the generic single-platform card (the common denominator
/// of Rank / Main / Milestone). Full and half differ visibly — the full card
/// shows a taller art band and up to one more headline stat (spec §5). Reads the
/// platform's card through the injected [CardSource]; loading/errored → the
/// neutral art placeholder with whatever stats resolve.
class PlatformCard extends ConsumerWidget {
  const PlatformCard({
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

    final isFull = size == ProfileCardSize.full;
    return PersonalizationCardShell(
      key: personalizationCardKey(widget.id),
      archetype: ProfileArchetype.platform,
      size: size,
      art: card?.heroImage,
      stats: cardStats(
        card,
        l10n,
        isFull
            ? PersonalizationLayout.statCapFull
            : PersonalizationLayout.statCapHalf,
      ),
    );
  }
}
