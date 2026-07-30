import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../connections/domain/connection.dart';
import '../../../connections/domain/game_card.dart';
import '../../domain/profile_archetype.dart';
import '../../domain/profile_header_resolver.dart';
import '../../domain/profile_widget.dart';
import '../art_framing_control.dart';
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
/// The owner adds it without choosing anything: left unpointed, it falls back
/// to the first linked platform that publishes any art, so it is born with a
/// picture whenever one exists anywhere. A stored source pins it to one
/// platform's art instead (the seam the image picker fills later). With no
/// picture from either path it renders the theme's ground: a quiet card, never
/// an error tile and never a broken-image glyph.
///
/// The fallback deliberately reads no profile preference. The cover and this
/// card share the rule that every image surface resolves something or falls
/// back — they do not share a choice. A card that followed the cover's pinned
/// platform would change every time the cover did, which is not what picking a
/// cover means.
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
    final String? art;
    if (source != null) {
      art = artOf(resolveCard(ref, cardSource, source));
    } else {
      art = resolveProfileHeader({
        for (final platform in Platform.values)
          platform: resolveCard(ref, cardSource, platform),
      }).art;
    }

    return PersonalizationCardShell(
      key: personalizationCardKey(widget.id),
      archetype: ProfileArchetype.art,
      size: size,
      art: art,
      framing: ArtFramingTarget(widgetId: widget.id, framing: widget.framing),
    );
  }
}

/// A card's art: the hero/cover when it has one, else the icon/avatar. The same
/// rule the profile header uses, so the picture a card shows and the picture
/// the header offers for it are the same picture.
String? artOf(GameCard? card) => card?.heroImage ?? card?.iconImage;
