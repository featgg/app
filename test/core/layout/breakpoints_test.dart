import 'package:featgg/src/core/layout/breakpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('windowSizeClassForWidth', () {
    // Half-open intervals matching design-system §9: compact 0–599,
    // medium 600–1023, expanded ≥1024. The boundary widths are the load-bearing
    // cases — a shifted `<` vs `<=` would misclassify a tablet as a phone.
    test('below the medium boundary is compact', () {
      expect(windowSizeClassForWidth(0), WindowSizeClass.compact);
      expect(windowSizeClassForWidth(599), WindowSizeClass.compact);
    });

    test('the medium boundary is inclusive', () {
      expect(windowSizeClassForWidth(600), WindowSizeClass.medium);
    });

    test('just below the expanded boundary is still medium', () {
      expect(windowSizeClassForWidth(1023), WindowSizeClass.medium);
    });

    test('the expanded boundary is inclusive', () {
      expect(windowSizeClassForWidth(1024), WindowSizeClass.expanded);
      expect(windowSizeClassForWidth(1600), WindowSizeClass.expanded);
    });

    test('the named boundaries are the design-system §9 values', () {
      expect(AppBreakpoints.medium, 600);
      expect(AppBreakpoints.expanded, 1024);
      expect(AppBreakpoints.maxContentWidth, 1200);
    });
  });
}
