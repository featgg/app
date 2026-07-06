/// Window size classes and their pixel boundaries.
///
/// The single source of truth for responsive layout thresholds, per
/// `architecture.md` (breakpoints defined once, centrally, as named values) and
/// `design-system.md` §9 (compact 0–599, medium 600–1023, expanded ≥1024).
/// Widgets read the size class via [windowSizeClassForWidth] and never compare
/// raw pixel widths inline.
library;

/// Material 3 window size class for a layout width.
enum WindowSizeClass { compact, medium, expanded }

/// Named breakpoint values from `design-system.md` §9. These are the boundaries
/// between window size classes (half-open intervals), plus the expanded-screen
/// max content width. Not Material 3's 840dp — the design system fixes 600/1024.
abstract final class AppBreakpoints {
  /// compact → medium boundary.
  static const double medium = 600;

  /// medium → expanded boundary.
  static const double expanded = 1024;

  /// Max content width on expanded, centered (design-system §9.2).
  static const double maxContentWidth = 1200;
}

/// Classifies a layout width (from `LayoutBuilder` constraints) into an M3
/// window size class. Design-system §9 owns the pixel values.
WindowSizeClass windowSizeClassForWidth(double width) =>
    width < AppBreakpoints.medium
    ? WindowSizeClass.compact
    : width < AppBreakpoints.expanded
    ? WindowSizeClass.medium
    : WindowSizeClass.expanded;
