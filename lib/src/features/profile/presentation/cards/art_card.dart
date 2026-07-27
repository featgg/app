import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../connections/domain/game_card.dart';
import '../../domain/profile_archetype.dart';
import '../../domain/profile_widget.dart';
import '../personalization_card_shell.dart';
import '../profile_owner_cards_provider.dart';
import 'card_data.dart';
import 'card_key.dart';

/// Art archetype: the picture is the card.
///
/// The only card in the catalog that answers nothing — no hero, no label, no
/// supporting stats. It exists because a profile is somebody's page and not
/// only their statement of record, and because the owner should be able to
/// decide that the first thing a visitor meets is an image.
///
/// Its subject is the art of a platform the owner picked, resolved the same way
/// every other card resolves art. A source that publishes none renders the
/// theme's ground: a card that lost its picture is a quiet card, never an error
/// tile and never a broken-image glyph.
class ArtCard extends ConsumerWidget {
  const ArtCard({
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
    final source = widget.artSelection.source;
    final card = source == null ? null : resolveCard(ref, cardSource, source);

    return PersonalizationCardShell(
      key: personalizationCardKey(widget.id),
      archetype: ProfileArchetype.art,
      size: size,
      art: artOf(card),
    );
  }
}

/// A card's art: the hero/cover when it has one, else the icon/avatar. The same
/// rule the profile header uses, so the picture a card shows and the picture
/// the header offers for it are the same picture.
String? artOf(GameCard? card) => card?.heroImage ?? card?.iconImage;
