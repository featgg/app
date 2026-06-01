import 'package:flutter/material.dart';

/// Seed for the Material 3 color scheme.
///
/// Provisional brand seed (dusty-rose accent) — the hue is not yet locked.
/// Confined here so a future swap touches one line.
abstract final class AppColorTokens {
  static const Color seed = Color(0xFFBC3B4E);
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
/// Six-step strictly-increasing scale. Monotonicity asserted in `tokens_test`
/// to catch accidental edits.
abstract final class AppRadii {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double full = 999;
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
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
}
