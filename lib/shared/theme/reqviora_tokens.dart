import 'package:flutter/material.dart';

/// Provisional REQVIORA design tokens.
/// Final brand approval is still pending.
abstract final class ReqvioraTokens {
  static const Color canvas = Color(0xFFF8F7FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF252338);
  static const Color textSecondary = Color(0xFF676477);
  static const Color accentPurple = Color(0xFF6750A4);
  static const Color accentSoft = Color(0xFFE8E1F4);
  static const Color outline = Color(0xFFDAD6E5);
  static const Color focusRing = Color(0xFF6750A4);

  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space40 = 40;
  static const double space48 = 48;

  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 20;

  static const double mobileBreakpoint = 600;
  static const double desktopBreakpoint = 1024;
  static const double maxContentWidth = 1120;

  static double horizontalPaddingFor(double width) {
    if (width < mobileBreakpoint) {
      return space16;
    }
    if (width < desktopBreakpoint) {
      return space24;
    }
    return space40;
  }

  static double verticalPaddingFor(double width) {
    if (width < mobileBreakpoint) {
      return space24;
    }
    return space40;
  }
}