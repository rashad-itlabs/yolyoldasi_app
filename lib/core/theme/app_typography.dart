import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Type scale for the app.
///
/// Inter is used because it ships complete Latin-Extended coverage, which the
/// Azerbaijani alphabet needs (ə, ğ, ı, İ, ö, ü, ç, ş). If the font cannot be
/// fetched, `google_fonts` silently falls back to the platform font and the
/// metrics below still apply.
abstract final class AppTypography {
  static TextTheme textTheme(Color primary, Color secondary) {
    TextStyle s(
      double size,
      FontWeight weight, {
      double? height,
      double? letterSpacing,
      Color? color,
    }) {
      return GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
        color: color ?? primary,
      );
    }

    return TextTheme(
      // Display — used sparingly: onboarding, empty states, big numbers.
      displayLarge: s(40, FontWeight.w700, height: 1.12, letterSpacing: -1.0),
      displayMedium: s(34, FontWeight.w700, height: 1.16, letterSpacing: -0.8),
      displaySmall: s(29, FontWeight.w700, height: 1.2, letterSpacing: -0.6),

      // Headline — page titles.
      headlineLarge: s(26, FontWeight.w700, height: 1.22, letterSpacing: -0.5),
      headlineMedium: s(23, FontWeight.w700, height: 1.26, letterSpacing: -0.4),
      headlineSmall: s(20, FontWeight.w600, height: 1.3, letterSpacing: -0.3),

      // Title — card headers, list item primary text.
      titleLarge: s(18, FontWeight.w600, height: 1.33, letterSpacing: -0.2),
      titleMedium: s(16, FontWeight.w600, height: 1.38, letterSpacing: -0.1),
      titleSmall: s(14, FontWeight.w600, height: 1.4),

      // Body — paragraphs and secondary list text.
      bodyLarge: s(16, FontWeight.w400, height: 1.5),
      bodyMedium: s(14, FontWeight.w400, height: 1.5, color: secondary),
      bodySmall: s(13, FontWeight.w400, height: 1.45, color: secondary),

      // Label — buttons, chips, overlines.
      labelLarge: s(15, FontWeight.w600, height: 1.2, letterSpacing: 0.1),
      labelMedium: s(13, FontWeight.w600, height: 1.2, letterSpacing: 0.2),
      labelSmall: s(11, FontWeight.w600, height: 1.2, letterSpacing: 0.5),
    );
  }

  /// Tabular figures — use for prices, seat counts and countdown timers so the
  /// layout does not jitter as digits change.
  static TextStyle tabular(TextStyle base) =>
      base.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}
