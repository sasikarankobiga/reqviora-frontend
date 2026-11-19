import 'package:flutter/material.dart';

import 'reqviora_tokens.dart';

/// Provisional light theme for the REQVIORA workspace.
/// Does not replace the current app-level MaterialApp theme.
abstract final class ReqvioraTheme {
  static ThemeData get light {
    const colors = ColorScheme.light(
      primary: ReqvioraTokens.accentPurple,
      onPrimary: Colors.white,
      surface: ReqvioraTokens.surface,
      onSurface: ReqvioraTokens.textPrimary,
      outline: ReqvioraTokens.outline,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: ReqvioraTokens.canvas,
      focusColor: ReqvioraTokens.focusRing,
      dividerColor: ReqvioraTokens.outline,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: ReqvioraTokens.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: ReqvioraTokens.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.5,
          color: ReqvioraTokens.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: ReqvioraTokens.textSecondary,
        ),
      ),
    );
  }
}