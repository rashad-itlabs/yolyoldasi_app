import 'package:flutter/material.dart';

/// Brand palette for Yol Yoldaşı.
///
/// The brand leans on an indigo that opens into violet — night roads and
/// distance rather than a utility green — balanced by a warm amber accent for
/// ratings, prices and highlights. Indigo and amber sit opposite each other on
/// the wheel, so a price or a star never has to fight the surface it is on.
abstract final class AppColors {
  // ---------------------------------------------------------------- brand
  static const Color brand50 = Color(0xFFEEF2FF);
  static const Color brand100 = Color(0xFFE0E7FF);
  static const Color brand200 = Color(0xFFC7D2FE);
  static const Color brand300 = Color(0xFFA5B4FC);
  static const Color brand400 = Color(0xFF818CF8);
  static const Color brand500 = Color(0xFF6366F1);
  static const Color brand600 = Color(0xFF4F46E5);
  static const Color brand700 = Color(0xFF4338CA);
  static const Color brand800 = Color(0xFF3730A3);
  static const Color brand900 = Color(0xFF312E81);

  /// The warm end of the brand. A ramp built from indigo alone reads as flat
  /// blue over a large area; bending the light end towards violet is what
  /// gives the hero its depth.
  static const Color violet300 = Color(0xFFA78BFA);
  static const Color violet500 = Color(0xFF8B5CF6);

  // ---------------------------------------------------------------- accent
  static const Color amber50 = Color(0xFFFFF6E5);
  static const Color amber200 = Color(0xFFFFD98A);
  static const Color amber400 = Color(0xFFF7B32B);
  static const Color amber500 = Color(0xFFE89B0C);
  static const Color amber700 = Color(0xFFB87706);

  // ------------------------------------------------ secondary / driver side
  // The original brand teal, demoted to the secondary. It is also what
  // [AppPalette.driverAccent] holds, ready for the driver surfaces to be
  // given the treatment the passenger home just got — nothing reads that
  // token yet.
  static const Color teal50 = Color(0xFFE6F7F3);
  static const Color teal100 = Color(0xFFBFEBE1);
  static const Color teal300 = Color(0xFF56C9B1);
  static const Color teal500 = Color(0xFF0F9A7D);
  static const Color teal600 = Color(0xFF0B7E66);
  static const Color teal700 = Color(0xFF086552);

  // ---------------------------------------------------------------- status
  static const Color success500 = Color(0xFF16A34A);
  static const Color success100 = Color(0xFFDCFCE7);
  static const Color successDark = Color(0xFF4ADE80);

  static const Color warning500 = Color(0xFFD97706);
  static const Color warning100 = Color(0xFFFEF3C7);
  static const Color warningDark = Color(0xFFFBBF24);

  static const Color danger500 = Color(0xFFDC2626);
  static const Color danger100 = Color(0xFFFEE2E2);
  static const Color dangerDark = Color(0xFFF87171);

  static const Color info500 = Color(0xFF2563EB);
  static const Color info100 = Color(0xFFDBEAFE);
  static const Color infoDark = Color(0xFF60A5FA);

  // ---------------------------------------------------------------- neutrals
  // Very slightly cool greys. They carry a trace of the brand hue so the page
  // sits under the indigo rather than beside it, but not enough to read as
  // blue on their own.
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral25 = Color(0xFFFBFBFD);
  static const Color neutral50 = Color(0xFFF5F6FA);
  static const Color neutral100 = Color(0xFFECEEF4);
  static const Color neutral200 = Color(0xFFDDE0EA);
  static const Color neutral300 = Color(0xFFC4C8D6);
  static const Color neutral400 = Color(0xFF979DB0);
  static const Color neutral500 = Color(0xFF6C7287);
  static const Color neutral600 = Color(0xFF4E5468);
  static const Color neutral700 = Color(0xFF3A3F50);
  static const Color neutral800 = Color(0xFF232636);
  static const Color neutral900 = Color(0xFF14161F);
  static const Color neutral950 = Color(0xFF0B0C12);
}

/// Semantic colours that Material's [ColorScheme] does not cover.
///
/// Accessed through `Theme.of(context).extension<AppPalette>()!` or, more
/// conveniently, `context.palette` from `core/extensions/context_extensions.dart`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.danger,
    required this.onDanger,
    required this.dangerContainer,
    required this.onDangerContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.accent,
    required this.onAccent,
    required this.border,
    required this.borderStrong,
    required this.surfaceElevated,
    required this.surfaceSunken,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.overlay,
    required this.driverAccent,
    required this.passengerAccent,
    required this.heroGradient,
    required this.passengerHero,
    required this.cardShadow,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;

  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  final Color danger;
  final Color onDanger;
  final Color dangerContainer;
  final Color onDangerContainer;

  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;

  /// Amber highlight used for prices, ratings and "premium" affordances.
  final Color accent;
  final Color onAccent;

  final Color border;
  final Color borderStrong;

  /// Card / sheet background that sits *above* [ColorScheme.surface].
  final Color surfaceElevated;

  /// Background that sits *below* the surface (page background, inputs).
  final Color surfaceSunken;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  final Color shimmerBase;
  final Color shimmerHighlight;

  /// Scrim used behind modals and image overlays.
  final Color overlay;

  final Color driverAccent;
  final Color passengerAccent;

  /// The brand gradient: the logo and the splash screen.
  final List<Color> heroGradient;

  /// The passenger home's header — the first thing a passenger sees and the
  /// biggest block of colour in the app.
  ///
  /// Three stops rather than two: a straight two-stop ramp reads flat across a
  /// block this large, while a mid stop bends it and gives it depth. It runs
  /// deep indigo → indigo → violet, deepest at the top-left where the greeting
  /// and title sit and the text needs contrast, lightest at the bottom-right,
  /// mostly behind the search card. Any number of stops is allowed — [lerp]
  /// walks the list.
  final List<Color> passengerHero;

  final List<BoxShadow> cardShadow;

  static const AppPalette light = AppPalette(
    success: AppColors.success500,
    onSuccess: AppColors.neutral0,
    successContainer: AppColors.success100,
    onSuccessContainer: Color(0xFF14532D),
    warning: AppColors.warning500,
    onWarning: AppColors.neutral0,
    warningContainer: AppColors.warning100,
    onWarningContainer: Color(0xFF78350F),
    danger: AppColors.danger500,
    onDanger: AppColors.neutral0,
    dangerContainer: AppColors.danger100,
    onDangerContainer: Color(0xFF7F1D1D),
    info: AppColors.info500,
    onInfo: AppColors.neutral0,
    infoContainer: AppColors.info100,
    onInfoContainer: Color(0xFF1E3A8A),
    accent: AppColors.amber500,
    onAccent: Color(0xFF3A2A00),
    border: AppColors.neutral200,
    borderStrong: AppColors.neutral300,
    surfaceElevated: AppColors.neutral0,
    surfaceSunken: AppColors.neutral50,
    textPrimary: AppColors.neutral900,
    textSecondary: AppColors.neutral600,
    // Darker than the neutral-400 it looks like it should be: tertiary text
    // still has to clear 4.5:1 against the page background.
    textTertiary: Color(0xFF666C80),
    shimmerBase: AppColors.neutral100,
    shimmerHighlight: AppColors.neutral50,
    overlay: Color(0x6614161F),
    driverAccent: AppColors.teal600,
    passengerAccent: AppColors.brand500,
    heroGradient: [AppColors.brand700, AppColors.violet500],
    passengerHero: [
      AppColors.brand900,
      AppColors.brand500,
      AppColors.violet300,
    ],
    cardShadow: [
      BoxShadow(color: Color(0x0F0B100F), blurRadius: 16, offset: Offset(0, 6)),
      BoxShadow(color: Color(0x0A0B100F), blurRadius: 2, offset: Offset(0, 1)),
    ],
  );

  static const AppPalette dark = AppPalette(
    success: AppColors.successDark,
    onSuccess: Color(0xFF052E16),
    successContainer: Color(0xFF14361F),
    onSuccessContainer: Color(0xFFBBF7D0),
    warning: AppColors.warningDark,
    onWarning: Color(0xFF3A2205),
    warningContainer: Color(0xFF3B2C10),
    onWarningContainer: Color(0xFFFDE68A),
    danger: AppColors.dangerDark,
    onDanger: Color(0xFF450A0A),
    dangerContainer: Color(0xFF401C1C),
    onDangerContainer: Color(0xFFFECACA),
    info: AppColors.infoDark,
    onInfo: Color(0xFF0B2454),
    infoContainer: Color(0xFF17294D),
    onInfoContainer: Color(0xFFBFDBFE),
    accent: AppColors.amber400,
    onAccent: Color(0xFF2E2100),
    border: Color(0xFF2A2D3C),
    borderStrong: Color(0xFF3B3F52),
    surfaceElevated: Color(0xFF1A1B25),
    surfaceSunken: Color(0xFF0B0C12),
    textPrimary: Color(0xFFECEEF4),
    textSecondary: Color(0xFFA7ACBF),
    textTertiary: Color(0xFF7E8497),
    shimmerBase: Color(0xFF1D2030),
    shimmerHighlight: Color(0xFF2A2D3C),
    overlay: Color(0x99000000),
    driverAccent: AppColors.teal300,
    passengerAccent: AppColors.brand300,
    heroGradient: [Color(0xFF2A2472), Color(0xFF6D5FD0)],
    // The same ramp two steps down, so the header lifts off a dark page
    // without glowing at it.
    passengerHero: [Color(0xFF1E1B4B), AppColors.brand700, Color(0xFF7C6BF0)],
    cardShadow: [
      BoxShadow(color: Color(0x52000000), blurRadius: 18, offset: Offset(0, 8)),
    ],
  );

  @override
  AppPalette copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? danger,
    Color? onDanger,
    Color? dangerContainer,
    Color? onDangerContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? accent,
    Color? onAccent,
    Color? border,
    Color? borderStrong,
    Color? surfaceElevated,
    Color? surfaceSunken,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? shimmerBase,
    Color? shimmerHighlight,
    Color? overlay,
    Color? driverAccent,
    Color? passengerAccent,
    List<Color>? heroGradient,
    List<Color>? passengerHero,
    List<BoxShadow>? cardShadow,
  }) {
    return AppPalette(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      onDangerContainer: onDangerContainer ?? this.onDangerContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      overlay: overlay ?? this.overlay,
      driverAccent: driverAccent ?? this.driverAccent,
      passengerAccent: passengerAccent ?? this.passengerAccent,
      heroGradient: heroGradient ?? this.heroGradient,
      passengerHero: passengerHero ?? this.passengerHero,
      cardShadow: cardShadow ?? this.cardShadow,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;

    /// Gradients are lerped stop by stop. The two themes always declare the
    /// same number of stops, but the clamp keeps a mismatch from throwing
    /// mid-animation.
    List<Color> ramp(List<Color> a, List<Color> b) => [
      for (var i = 0; i < a.length; i++) c(a[i], b[i.clamp(0, b.length - 1)]),
    ];

    return AppPalette(
      success: c(success, other.success),
      onSuccess: c(onSuccess, other.onSuccess),
      successContainer: c(successContainer, other.successContainer),
      onSuccessContainer: c(onSuccessContainer, other.onSuccessContainer),
      warning: c(warning, other.warning),
      onWarning: c(onWarning, other.onWarning),
      warningContainer: c(warningContainer, other.warningContainer),
      onWarningContainer: c(onWarningContainer, other.onWarningContainer),
      danger: c(danger, other.danger),
      onDanger: c(onDanger, other.onDanger),
      dangerContainer: c(dangerContainer, other.dangerContainer),
      onDangerContainer: c(onDangerContainer, other.onDangerContainer),
      info: c(info, other.info),
      onInfo: c(onInfo, other.onInfo),
      infoContainer: c(infoContainer, other.infoContainer),
      onInfoContainer: c(onInfoContainer, other.onInfoContainer),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      surfaceElevated: c(surfaceElevated, other.surfaceElevated),
      surfaceSunken: c(surfaceSunken, other.surfaceSunken),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      shimmerBase: c(shimmerBase, other.shimmerBase),
      shimmerHighlight: c(shimmerHighlight, other.shimmerHighlight),
      overlay: c(overlay, other.overlay),
      driverAccent: c(driverAccent, other.driverAccent),
      passengerAccent: c(passengerAccent, other.passengerAccent),
      heroGradient: ramp(heroGradient, other.heroGradient),
      passengerHero: ramp(passengerHero, other.passengerHero),
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t)!,
    );
  }
}
