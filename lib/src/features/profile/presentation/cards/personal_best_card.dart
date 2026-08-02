import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/core.dart';
import '../../domain/personal_best_value_resolver.dart';
import '../../domain/profile_archetype.dart';
import '../../domain/profile_widget.dart';
import '../personalization_card_shell.dart';
import '../profile_owner_cards_provider.dart';
import 'card_data.dart';
import 'card_key.dart';

/// Personal Best archetype: "the best I have ever done" — the peak figure the
/// owner has ever reached on the bound platform, with the mode it belongs to
/// named beside it, and the live figure that says how far from it they stand.
/// Folds the bound platform's card through the pure [resolvePersonalBest]; a
/// payload with no peak renders a neutral no-data card, never a stale or
/// borrowed figure.
class PersonalBestCard extends ConsumerWidget {
  const PersonalBestCard({
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
    final resolved = resolvePersonalBest(card);

    // Only stats: the shell promotes the first entry to the hero and caps the
    // rest by size, so the half carries the peak alone and the full adds the
    // live figure without this card doing arithmetic of its own.
    return PersonalizationCardShell(
      key: personalizationCardKey(widget.id),
      archetype: ProfileArchetype.personalBest,
      size: size,
      stats: personalBestStats(resolved, l10n),
    );
  }
}
