import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/core/theme/personalization_tokens.dart';
import 'package:featgg/src/features/connections/domain/platform_descriptor.dart';
import 'package:featgg/src/features/profile/presentation/cards/card_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

/// The width a stat label actually gets on the narrowest card the column
/// supports: a half card, less the datum's own horizontal padding on both
/// sides. Measured here rather than assumed, because every label written for a
/// card is written against this number.
const _labelBudget =
    goldenHalfWidth - 2 * PersonalizationLayout.datumHorizontalPadding;

/// What a *supporting* label gets, which is far less and is the case a budget
/// taken from a half card misses: on a full card the hero and two stats share
/// one row, so each is about a third of it. Measured because reading the first
/// version of this off the wider number let a label through that truncated.
const _supportingBudget =
    (goldenFullWidth -
        2 * PersonalizationLayout.datumHorizontalPadding -
        2 * PersonalizationLayout.datumEntryGap) /
    (1 + PersonalizationLayout.supportingCapFull);

/// Lays out [text] the way the datum does — uppercase, tracked, at the label
/// size a half card gives it — and reports how wide it comes out.
double _labelWidth(String text) {
  final painter = TextPainter(
    text: TextSpan(
      text: text.toUpperCase(),
      style: TextStyle(
        fontFamily: goldenFontFamily,
        fontSize: PersonalizationLayout.datumLabelMin,
        letterSpacing: PersonalizationLayout.labelTracking,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return painter.width;
}

void main() {
  // Untagged, like the harness guards: a label that does not fit is a defect a
  // developer needs to see while writing the label, not a reference image
  // rendered later.

  testWidgets('the label budget is wide enough to be worth writing to', (
    tester,
  ) async {
    // Guards the measurement itself. If padding or the column floor changed
    // enough to leave a handful of characters, every label below would "pass"
    // by being unwritable rather than by fitting.
    expect(_labelBudget, greaterThan(80));
  });

  testWidgets('every platform short name leaves room for what it names', (
    tester,
  ) async {
    // The property the vocabulary exists for: each one prefixes a noun and both
    // still fit. Every platform, not the longest — a card is written per
    // platform and any one of them overflowing is a truncated label on someone's
    // profile.
    for (final descriptor in platformDescriptors.values) {
      final width = _labelWidth('${descriptor.shortName} hours');
      expect(
        width,
        lessThanOrEqualTo(_labelBudget),
        reason:
            '"${descriptor.shortName} hours" needs '
            '${width.toStringAsFixed(1)}pt of '
            '${_labelBudget.toStringAsFixed(1)}pt',
      );
    }
  });

  testWidgets('every card label fits, in every language', (tester) async {
    // The acceptance this story turns on, asserted over the real strings rather
    // than a sample: a label that overflows is a number whose subject a reader
    // cannot read, which is the defect the copy exists to remove.
    //
    // A prefixed label is measured against the longest platform name, because
    // that is the one that has to fit — a noun sized to WoW and overflowing on
    // Hypixel is a label that truncates on somebody's profile.
    final longestPlatform = platformDescriptors.values
        .map((descriptor) => descriptor.shortName)
        .reduce((a, b) => _labelWidth(a) >= _labelWidth(b) ? a : b);

    final failures = <String>[];
    for (final tag in ['en', 'es', 'pt']) {
      final l10n = await AppLocalizations.delegate.load(Locale(tag));
      for (final key in cardStatKeys) {
        final noun = cardStatLabel(l10n, key)!;
        final label = cardStatNeedsPlatform(key)
            ? '$longestPlatform $noun'
            : noun;
        final width = _labelWidth(label);
        if (width > _labelBudget) {
          failures.add(
            '$tag/$key: "${label.toUpperCase()}" '
            '${width.toStringAsFixed(1)}pt',
          );
        }
      }
    }

    expect(
      failures,
      isEmpty,
      reason:
          'over the ${_labelBudget.toStringAsFixed(1)}pt a label gets:\n'
          '${failures.join('\n')}',
    );
  });

  testWidgets('every card label fits beside a hero, in every language', (
    tester,
  ) async {
    // The case the budget above misses, and the one a rendered card caught after
    // this file was already green: a label explaining the hero gets a third of a
    // row, not the whole of one. Only the hero carries a platform, so what is
    // measured here is the bare noun — but it is measured against the width it
    // really has.
    final failures = <String>[];
    for (final tag in ['en', 'es', 'pt']) {
      final l10n = await AppLocalizations.delegate.load(Locale(tag));
      for (final key in cardStatKeys) {
        final width = _labelWidth(cardStatLabel(l10n, key)!);
        if (width > _supportingBudget) {
          failures.add(
            '$tag/$key: "${cardStatLabel(l10n, key)!.toUpperCase()}" '
            '${width.toStringAsFixed(1)}pt',
          );
        }
      }
    }

    expect(
      failures,
      isEmpty,
      reason:
          'over the ${_supportingBudget.toStringAsFixed(1)}pt a supporting '
          'label gets:\n${failures.join('\n')}',
    );
  });

  testWidgets('the short names are load-bearing, not cosmetic', (tester) async {
    // Without this the test above would pass for a vocabulary that changed
    // nothing. Not every brand name overflows — Chess.com fits as it is — so
    // the claim is that the longest one does, which is what made a shorter
    // vocabulary necessary rather than tidy.
    final longest = platformDescriptors.values
        .map((descriptor) => descriptor.displayName)
        .reduce((a, b) => _labelWidth(a) >= _labelWidth(b) ? a : b);

    expect(
      _labelWidth('$longest hours'),
      greaterThan(_labelBudget),
      reason: '$longest fit after all',
    );
  });
}
