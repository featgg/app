import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/profile/presentation/cards/card_data.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

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

  test('a sub-1% rarity keeps the decimals that make it rare', () async {
    final l10n = await _l10n('en');

    // The adversarial case against reusing formatCardValue: it rounds to a
    // whole number, so the documented 0.31 would render as 0 — a card claiming
    // nobody has the achievement the owner is holding.
    final rendered = formatRarityValue(0.31, l10n);
    expect(rendered, contains('31'));
    expect(rendered, isNot(formatRarityValue(0, l10n)));
  });

  test('the decimal count follows the magnitude', () async {
    final l10n = await _l10n('en');

    // Two decimals below 1%, one below 10%, none above: the band boundaries
    // are asserted so the ladder cannot drift.
    // The exact floor belongs to the stated side, not the bound: 0.01 is the
    // finest rarity the card states as-is, and asserting it literally is what
    // keeps the floor comparison strict.
    expect(formatRarityValue(0.01, l10n), '0.01%');
    expect(formatRarityValue(0.5, l10n), '0.50%');
    expect(formatRarityValue(1, l10n), '1.0%');
    expect(formatRarityValue(9.9, l10n), '9.9%');
    expect(formatRarityValue(10, l10n), '10%');
    expect(formatRarityValue(100, l10n), '100%');
  });

  test('a rarity finer than the card states renders as a bound, never as '
      'zero', () async {
    final l10n = await _l10n('en');

    // An ultra-rare achievement is the strongest thing this card can show;
    // rendering it as 0.00% would hide exactly the best case. The adversarial
    // rendering is built the way a formatter without the bound would build it,
    // so dropping the bound turns this red.
    final roundedZero = NumberFormat.decimalPercentPattern(
      locale: l10n.localeName,
      decimalDigits: 2,
    ).format(0);
    // The bound the card states instead, composed from the same public surface
    // rather than spelled out.
    final bound = l10n.cardValueRarityBelow(formatRarityValue(0.01, l10n));
    for (final pct in const [0.0001, 0.004, 0.009]) {
      final rendered = formatRarityValue(pct, l10n);
      expect(
        rendered,
        isNot(roundedZero),
        reason: '$pct rendered as "$rendered"',
      );
      expect(rendered, bound, reason: '$pct rendered as "$rendered"');
    }
  });

  test(
    'the percent form follows the locale, not a symbol written here',
    () async {
      final en = await _l10n('en');
      final es = await _l10n('es');
      final pt = await _l10n('pt');

      // A hand-written '%' with a '.' separator would satisfy the English
      // assertions above and be wrong in the other two languages the app ships.
      final rendered = {
        formatRarityValue(0.31, en),
        formatRarityValue(0.31, es),
        formatRarityValue(0.31, pt),
      };
      expect(
        rendered.length,
        greaterThan(1),
        reason: 'every locale rendered 0.31 identically: $rendered',
      );
    },
  );

  test('a fractional value does not carry its decimal onto the card', () async {
    final l10n = await _l10n('en');

    // Hours arrive fractional from one platform and whole from another; a card
    // shows the same shape either way.
    expect(formatCardValue(12.0, l10n), '12');
    expect(formatCardValue(1200.0, l10n), formatCardValue(1200, l10n));
    // The case the magnitude threshold does not catch on its own: a value well
    // inside the spelled-out range still overflows a supporting slot once a
    // decimal rides along, so the fraction goes rather than the digits.
    expect(formatCardValue(1234.5, l10n), formatCardValue(1235, l10n));
    expect(formatCardValue(1234.5, l10n), isNot(contains('.')));
  });
}
