import 'package:featgg/src/core/theme/theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSpacing', () {
    test('spacing scale is strictly increasing', () {
      expect(AppSpacing.xs, lessThan(AppSpacing.sm));
      expect(AppSpacing.sm, lessThan(AppSpacing.smMd));
      expect(AppSpacing.smMd, lessThan(AppSpacing.md));
      expect(AppSpacing.md, lessThan(AppSpacing.lg));
      expect(AppSpacing.lg, lessThan(AppSpacing.xl));
    });
  });

  group('AppRadii', () {
    test('radius scale is strictly increasing', () {
      expect(AppRadii.xs, lessThan(AppRadii.sm));
      expect(AppRadii.sm, lessThan(AppRadii.md));
      expect(AppRadii.md, lessThan(AppRadii.lg));
      expect(AppRadii.lg, lessThan(AppRadii.xl));
      expect(AppRadii.xl, lessThan(AppRadii.full));
    });
  });

  group('AppSheet', () {
    test('max-height fraction is a sane in-range screen cap', () {
      // A screen-height fraction: must stay above zero and never exceed the
      // full screen, or the content-sized sheet cap loses meaning.
      expect(AppSheet.maxHeightFraction, greaterThan(0));
      expect(AppSheet.maxHeightFraction, lessThanOrEqualTo(1));
    });
  });

  group('AppColorTokens', () {
    test('seed is the declared value', () {
      // Guards accidental drift of the single source of truth for the brand seed.
      expect(AppColorTokens.seed.toARGB32(), equals(0xFFBC3B4E));
    });
  });
}
