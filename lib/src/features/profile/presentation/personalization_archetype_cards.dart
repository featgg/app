import 'package:flutter/material.dart';
import '../../../core/core.dart';
import '../domain/profile_archetype.dart';
import '../domain/profile_widget.dart';
import 'profile_owner_cards_provider.dart';
import 'cards/achievement_grid_card.dart';
import 'cards/art_card.dart';
import 'cards/collection_card.dart';
import 'cards/identity_card.dart';
import 'cards/main_card.dart';
import 'cards/milestone_card.dart';
import 'cards/platform_card.dart';
import 'cards/rank_card.dart';

export 'cards/achievement_grid_card.dart';
export 'cards/art_card.dart';
export 'cards/card_data.dart';
export 'cards/card_key.dart';
export 'cards/collection_card.dart';
export 'cards/identity_card.dart';
export 'cards/main_card.dart';
export 'cards/milestone_card.dart';
export 'cards/platform_card.dart';
export 'cards/rank_card.dart';

/// Builds the archetype card for [widget] at [size]. A full-only archetype in a
/// half slot renders full within its column. Shared by the read view and the
/// editor so both build identical cards from one place.
Widget personalizationCardFor(
  ProfileWidget widget, {
  required ProfileCardSize size,
  CardSource? cardSource,
  DateTime? memberSince,
}) {
  final archetype = archetypeForWidget(widget);
  final effectiveSize = supportedSizes(archetype).contains(size)
      ? size
      : ProfileCardSize.full;
  return switch (archetype) {
    ProfileArchetype.identity => IdentityCard(
      widget: widget,
      cardSource: cardSource,
      memberSince: memberSince,
    ),
    ProfileArchetype.platform => PlatformCard(
      widget: widget,
      size: effectiveSize,
      cardSource: cardSource,
    ),
    ProfileArchetype.milestone => MilestoneCard(
      widget: widget,
      size: effectiveSize,
      cardSource: cardSource,
    ),
    ProfileArchetype.rank => RankCard(
      widget: widget,
      size: effectiveSize,
      cardSource: cardSource,
    ),
    ProfileArchetype.main => MainCard(
      widget: widget,
      size: effectiveSize,
      cardSource: cardSource,
    ),
    // Collection and Achievement Grid are full-only, so they ignore [size].
    ProfileArchetype.collection => CollectionCard(
      widget: widget,
      cardSource: cardSource,
    ),
    ProfileArchetype.achievementGrid => AchievementGridCard(
      widget: widget,
      cardSource: cardSource,
    ),
    ProfileArchetype.art => ArtCard(
      widget: widget,
      size: effectiveSize,
      cardSource: cardSource,
    ),
  };
}

/// Arranges a pair row's two slot widgets: both present → a two-up Row; exactly
/// one → a centered half; none → nothing. Shared by the read view and the editor
/// so pair/orphan geometry is identical.
Widget personalizationPairFrame({
  required Widget? left,
  required Widget? right,
}) {
  if (left == null && right == null) return const SizedBox.shrink();
  if (left == null || right == null) {
    return Align(
      alignment: Alignment.center,
      child: FractionallySizedBox(
        widthFactor: PersonalizationLayout.orphanWidthFactor,
        child: left ?? right,
      ),
    );
  }
  // Stretch alone is illegal in a column whose height is unbounded;
  // IntrinsicHeight bounds the row to the taller card, and stretch then hands
  // both slots that height so a pair always ends on one line.
  return IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: left),
        const SizedBox(width: PersonalizationLayout.rowGap),
        Expanded(child: right),
      ],
    ),
  );
}
