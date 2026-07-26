import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/core.dart';
import '../../domain/main_value_resolver.dart';
import '../../domain/profile_archetype.dart';
import '../../domain/profile_widget.dart';
import '../personalization_card_shell.dart';
import '../profile_owner_cards_provider.dart';
import 'card_data.dart';
import 'card_key.dart';

/// Main archetype (spec §7): "what defines me" — the primary game / character /
/// mode's cover fills the card, with its name and 2–3 headline numbers in the
/// datum. Folds the bound platform's card through the pure [resolveMain]; a
/// payload with no main renders a neutral no-data card over the archetype's
/// motif, never a fallback.
class MainCard extends ConsumerWidget {
  const MainCard({
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
    final resolved = resolveMain(card);

    final isFull = size == ProfileCardSize.full;
    return PersonalizationCardShell(
      key: personalizationCardKey(widget.id),
      archetype: ProfileArchetype.main,
      size: size,
      art: resolved?.heroImage,
      subject: resolved?.title ?? l10n.personalizationMainTopChampion,
      detail: resolved?.subtitle,
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
