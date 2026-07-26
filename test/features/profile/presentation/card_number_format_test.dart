import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/profile/presentation/cards/card_data.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppLocalizations> _l10n(String tag) =>
    AppLocalizations.delegate.load(Locale(tag));

void main() {
  test('a value a card can hold renders as itself', () async {
    final l10n = await _l10n('en');

    expect(formatCardValue(0, l10n), '0');
    expect(formatCardValue(3, l10n), '3');
    expect(formatCardValue(300, l10n), '300');
  });

  test('a four-digit value is still spelled out', () async {
    final l10n = await _l10n('en');

    // Compact notation is the remedy for a value that does not fit, not the
    // default: at this magnitude it costs the same width and throws away
    // precision the card had room to show.
    expect(formatCardValue(1200, l10n), contains('200'));
    expect(formatCardValue(9999, l10n), contains('999'));
  });

  test(
    'a value past what a card can hold switches to compact notation',
    () async {
      final l10n = await _l10n('en');

      for (final value in [10000, 87654321, 1234567890123]) {
        final text = formatCardValue(value, l10n);
        expect(
          text.length,
          lessThan(value.toString().length),
          reason: '$value rendered as "$text"',
        );
      }
    },
  );

  test(
    'compact notation follows the locale, not a suffix written here',
    () async {
      final en = await _l10n('en');
      final es = await _l10n('es');
      final pt = await _l10n('pt');

      // The adversarial case for this story: a hardcoded 'K' would satisfy
      // every other assertion here and be wrong in two of the three languages
      // the app ships. The value has to sit above the compact threshold, or
      // this passes on the thousands separator alone and never reads the suffix
      // it exists to check.
      const value = 1200000;
      final rendered = {
        formatCardValue(value, en),
        formatCardValue(value, es),
        formatCardValue(value, pt),
      };
      expect(
        rendered.length,
        greaterThan(1),
        reason: 'every locale rendered $value identically: $rendered',
      );
    },
  );

  test('no magnitude a platform can publish renders wide', () async {
    final l10n = await _l10n('en');

    // The layout cannot be left at the mercy of how large a number an upstream
    // account happens to hold, so the widest possible value is what this bounds
    // — a lifetime achievement-point total, an account age in hours.
    for (final value in [
      1000,
      9999,
      12345,
      999999,
      1000000,
      87654321,
      999999999,
      1234567890123,
    ]) {
      final text = formatCardValue(value, l10n);
      expect(
        text.length,
        lessThanOrEqualTo(6),
        reason: '$value rendered as "$text"',
      );
    }
  });

  test('a fractional value does not carry its decimal onto the card', () async {
    final l10n = await _l10n('en');

    // Hours arrive fractional from one platform and whole from another; a card
    // shows the same shape either way.
    expect(formatCardValue(12.0, l10n), '12');
    expect(formatCardValue(1200.0, l10n), formatCardValue(1200, l10n));
  });
}
