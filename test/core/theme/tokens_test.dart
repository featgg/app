import 'package:featgg/src/core/theme/theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSpacing', () {
    test('spacing scale is strictly increasing', () {
      expect(AppSpacing.xs, lessThan(AppSpacing.sm));
      expect(AppSpacing.sm, lessThan(AppSpacing.md));
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

  group('AppColorTokens', () {
    test('seed is the declared value', () {
      // Guards accidental drift of the single source of truth for the brand seed.
      expect(AppColorTokens.seed.toARGB32(), equals(0xFFBC3B4E));
    });
  });
}
