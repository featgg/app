import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/core.dart';
import '../../domain/profile_archetype.dart';
import '../../domain/profile_widget.dart';
import '../personalization_card_shell.dart';
import '../profile_owner_cards_provider.dart';
import 'card_data.dart';
import 'card_key.dart';

/// Fallback archetype for any kind without a built card:
/// a safe, never-blank card — whatever art the envelope carries and any
/// resolvable stats. Keeps an unrecognized layout slot from crashing or reading
/// as empty.
class FallbackCard extends ConsumerWidget {
  const FallbackCard({
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

    return PersonalizationCardShell(
      key: personalizationCardKey(widget.id),
      archetype: ProfileArchetype.fallback,
      size: size,
      art: card?.heroImage,
      stats: cardStats(card, l10n, PersonalizationLayout.statCapFull),
    );
  }
}
