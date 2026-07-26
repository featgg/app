import 'package:flutter/material.dart';

/// Stable key for a rendered archetype card, keyed by the composing widget id so
/// the layout composition (order, presence) is assertable independent of the
/// card's inner content.
Key personalizationCardKey(String widgetId) =>
    Key('personalizationCard_$widgetId');

/// Stable key for a Collection orb (curated: one per resolved game; Collector:
/// the single library emblem), so the per-game orbs and the token-gradient art
/// (theme inheritance) are assertable.
Key collectionOrbKey(String widgetId, int index) =>
    Key('personalizationCollectionOrb_${widgetId}_$index');

/// Stable key for an Achievement Grid letter tile (one per resolved perfect-game
/// shelf entry), so the letter motif and its accent tint are assertable.
Key achievementLetterKey(String widgetId, int index) =>
    Key('personalizationAchievementLetter_${widgetId}_$index');
