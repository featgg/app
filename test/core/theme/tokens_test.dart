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
      expect(AppRadii.sm, lessThan(AppRadii.md));
      expect(AppRadii.md, lessThan(AppRadii.lg));
    });
  });

  group('AppColorTokens', () {
    test('seed is the declared placeholder value', () {
      // Guards accidental drift of the single source of truth.
      expect(AppColorTokens.seed.toARGB32(), equals(0xFF4F46E5));
    });
  });
}
