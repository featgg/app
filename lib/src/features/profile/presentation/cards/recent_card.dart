import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/core.dart';
import '../../domain/profile_archetype.dart';
import '../../domain/profile_widget.dart';
import '../../domain/recent_value_resolver.dart';
import '../art_framing_control.dart';
import '../personalization_card_shell.dart';
import '../profile_owner_cards_provider.dart';
import 'card_data.dart';
import 'card_key.dart';

/// Recent archetype: "what I am playing lately" — the recently-played game's
/// cover fills the card, with its name and the platform's recent-playtime figure
/// in the datum. Folds the bound platform's card through the pure
/// [resolveRecent]; a payload with no recent activity renders a neutral no-data
/// card, never the previous game.
class RecentCard extends ConsumerWidget {
  const RecentCard({
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
    final resolved = resolveRecent(card);

    return PersonalizationCardShell(
      key: personalizationCardKey(widget.id),
      archetype: ProfileArchetype.recent,
      size: size,
      art: resolved?.heroImage,
      framing: ArtFramingTarget(widgetId: widget.id, framing: widget.framing),
      subject: resolved?.title,
      // Without art nothing else on the card can say which account the figure
      // came from, so the platform is named here rather than beside the number:
      // this line has a full line to itself.
      detail: resolved == null
          ? null
          : cardLabelPlatform(platform, hasArt: resolved.heroImage != null),
      stats: statsFromResolved(
        resolved?.stats ?? const [],
        l10n,
        PersonalizationLayout.statCapFull,
      ),
    );
  }
}
