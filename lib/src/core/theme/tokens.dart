import 'package:flutter/material.dart';

/// Seed for the Material 3 color scheme.
///
/// A KISS placeholder pending a brand design system — the specific hue is not
/// a finished brand decision. Confined here so a future swap touches one line.
abstract final class AppColorTokens {
  static const Color seed = Color(0xFF4F46E5);
}

/// Spacing scale in logical pixels.
///
/// Four-point base with a xl breakpoint. Strictly increasing — the
/// `tokens_test` asserts monotonicity to catch accidental edits.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Border-radius scale in logical pixels.
///
/// Strictly increasing — monotonicity asserted in `tokens_test`.
abstract final class AppRadii {
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 16;
}

/// Font-family-agnostic type scale.
///
/// Sizes and weights only — no `fontFamily`. The platform default font is used
/// until a brand font is selected, avoiding a runtime network dependency.
abstract final class AppTypography {
  static const double displaySize = 32;
  static const double titleSize = 20;
  static const double bodySize = 16;
  static const double labelSize = 14;
  static const double captionSize = 12;

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight bold = FontWeight.w700;
}
