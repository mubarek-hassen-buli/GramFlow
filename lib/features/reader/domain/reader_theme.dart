import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reading canvas color theme.
enum ReaderTheme {
  paper, // Clean white paper background
  sepia, // Warm eye-friendly paper tone
  dark, // Low-glare dark grey
  black, // True OLED black
}

extension ReaderThemeColors on ReaderTheme {
  Color get backgroundColor => switch (this) {
    ReaderTheme.paper => const Color(0xFFFAF9F6),
    ReaderTheme.sepia => const Color(0xFFF6EEDF),
    ReaderTheme.dark => const Color(0xFF1E1E20),
    ReaderTheme.black => const Color(0xFF000000),
  };

  Color get surfaceColor => switch (this) {
    ReaderTheme.paper => const Color(0xFFF0EFEA),
    ReaderTheme.sepia => const Color(0xFFEFE4D0),
    ReaderTheme.dark => const Color(0xFF28282B),
    ReaderTheme.black => const Color(0xFF161618),
  };

  Color get primaryTextColor => switch (this) {
    ReaderTheme.paper => const Color(0xFF1A1A1A),
    ReaderTheme.sepia => const Color(0xFF382C1E),
    ReaderTheme.dark => const Color(0xFFE8E8E8),
    ReaderTheme.black => const Color(0xFFF2F2F2),
  };

  Color get secondaryTextColor => switch (this) {
    ReaderTheme.paper => const Color(0xFF6E6E73),
    ReaderTheme.sepia => const Color(0xFF7D6852),
    ReaderTheme.dark => const Color(0xFF9E9EA4),
    ReaderTheme.black => const Color(0xFF88888D),
  };

  Color get dividerColor => switch (this) {
    ReaderTheme.paper => const Color(0xFFE5E4DE),
    ReaderTheme.sepia => const Color(0xFFE2D6C0),
    ReaderTheme.dark => const Color(0xFF333336),
    ReaderTheme.black => const Color(0xFF222224),
  };

  Brightness get brightness => switch (this) {
    ReaderTheme.paper || ReaderTheme.sepia => Brightness.light,
    ReaderTheme.dark || ReaderTheme.black => Brightness.dark,
  };
}

/// Editorial typeface family.
enum ReaderFont {
  serif, // Merriweather
  sans, // Inter
  mono, // JetBrains Mono
}

extension ReaderFontStyles on ReaderFont {
  TextStyle style({
    required double fontSize,
    required double lineHeight,
    required Color color,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    switch (this) {
      case ReaderFont.serif:
        return GoogleFonts.merriweather(
          fontSize: fontSize,
          height: lineHeight,
          color: color,
          fontWeight: fontWeight,
        );
      case ReaderFont.sans:
        return GoogleFonts.inter(
          fontSize: fontSize,
          height: lineHeight,
          color: color,
          fontWeight: fontWeight,
        );
      case ReaderFont.mono:
        return GoogleFonts.jetBrainsMono(
          fontSize: fontSize * 0.9,
          height: lineHeight,
          color: color,
          fontWeight: fontWeight,
        );
    }
  }
}
