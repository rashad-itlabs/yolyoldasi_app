import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_typography.dart';

/// Builds the light and dark [ThemeData] for the whole app.
///
/// Everything is defined once here: no widget should hard-code a colour, a
/// radius or a shadow.
abstract final class AppTheme {
  /// Built once. `MaterialApp` compares themes by identity in places, so
  /// handing it a fresh `ThemeData` on every rebuild would invalidate more of
  /// the tree than necessary.
  static final ThemeData light = _build(_lightScheme, AppPalette.light);

  static final ThemeData dark = _build(_darkScheme, AppPalette.dark);

  // ------------------------------------------------------------------ schemes
  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.brand600,
    onPrimary: AppColors.neutral0,
    primaryContainer: AppColors.brand50,
    onPrimaryContainer: AppColors.brand900,
    // Teal, the app's original brand colour, kept as the second voice.
    secondary: AppColors.teal500,
    onSecondary: AppColors.neutral0,
    secondaryContainer: AppColors.teal50,
    onSecondaryContainer: AppColors.teal700,
    tertiary: AppColors.amber500,
    onTertiary: AppColors.neutral0,
    tertiaryContainer: AppColors.amber50,
    onTertiaryContainer: AppColors.amber700,
    error: AppColors.danger500,
    onError: AppColors.neutral0,
    errorContainer: AppColors.danger100,
    onErrorContainer: Color(0xFF7F1D1D),
    surface: AppColors.neutral25,
    onSurface: AppColors.neutral900,
    surfaceDim: AppColors.neutral100,
    surfaceBright: AppColors.neutral0,
    surfaceContainerLowest: AppColors.neutral0,
    surfaceContainerLow: AppColors.neutral25,
    surfaceContainer: AppColors.neutral50,
    surfaceContainerHigh: AppColors.neutral100,
    surfaceContainerHighest: AppColors.neutral200,
    onSurfaceVariant: AppColors.neutral600,
    outline: AppColors.neutral300,
    outlineVariant: AppColors.neutral200,
    shadow: AppColors.neutral950,
    scrim: AppColors.neutral950,
    inverseSurface: AppColors.neutral900,
    onInverseSurface: AppColors.neutral50,
    inversePrimary: AppColors.brand300,
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.brand300,
    onPrimary: Color(0xFF1E1B4B),
    primaryContainer: AppColors.brand900,
    onPrimaryContainer: AppColors.brand100,
    secondary: AppColors.teal300,
    onSecondary: Color(0xFF00382C),
    secondaryContainer: Color(0xFF0A4A3D),
    onSecondaryContainer: AppColors.teal100,
    tertiary: AppColors.amber400,
    onTertiary: Color(0xFF3A2A00),
    tertiaryContainer: Color(0xFF574000),
    onTertiaryContainer: AppColors.amber200,
    error: AppColors.dangerDark,
    onError: Color(0xFF450A0A),
    errorContainer: Color(0xFF401C1C),
    onErrorContainer: Color(0xFFFECACA),
    surface: Color(0xFF12131B),
    onSurface: Color(0xFFECEEF4),
    surfaceDim: Color(0xFF0B0C12),
    surfaceBright: Color(0xFF2A2D3C),
    surfaceContainerLowest: Color(0xFF07080D),
    surfaceContainerLow: Color(0xFF12131B),
    surfaceContainer: Color(0xFF1A1B25),
    surfaceContainerHigh: Color(0xFF23252F),
    surfaceContainerHighest: Color(0xFF2D3040),
    onSurfaceVariant: Color(0xFFA7ACBF),
    outline: Color(0xFF3B3F52),
    outlineVariant: Color(0xFF2A2D3C),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFECEEF4),
    onInverseSurface: Color(0xFF1A1B25),
    inversePrimary: AppColors.brand600,
  );

  // -------------------------------------------------------------------- build
  static ThemeData _build(ColorScheme scheme, AppPalette palette) {
    final isLight = scheme.brightness == Brightness.light;
    final text = AppTypography.textTheme(
      palette.textPrimary,
      palette.textSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: scheme.brightness,
      scaffoldBackgroundColor: palette.surfaceSunken,
      canvasColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      textTheme: text,
      extensions: <ThemeExtension<dynamic>>[palette],

      // ------------------------------------------------------------- app bar
      appBarTheme: AppBarThemeData(
        backgroundColor: palette.surfaceSunken,
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleSpacing: Gap.page,
        toolbarHeight: 60,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: palette.textPrimary, size: Sizes.icon),
        actionsIconTheme: IconThemeData(
          color: palette.textPrimary,
          size: Sizes.icon,
        ),
        systemOverlayStyle: isLight
            ? SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: palette.surfaceSunken,
                systemNavigationBarIconBrightness: Brightness.dark,
              )
            : SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: palette.surfaceSunken,
                systemNavigationBarIconBrightness: Brightness.light,
              ),
      ),

      // --------------------------------------------------------------- cards
      cardTheme: CardThemeData(
        color: palette.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.lgAll,
          side: BorderSide(color: palette.border),
        ),
      ),

      // ------------------------------------------------------------- buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(Sizes.buttonHeight),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: palette.border,
          disabledForegroundColor: palette.textTertiary,
          textStyle: text.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
          padding: const EdgeInsets.symmetric(horizontal: Gap.xxl),
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(Sizes.buttonHeight),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: text.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(Sizes.buttonHeight),
          foregroundColor: palette.textPrimary,
          textStyle: text.labelLarge,
          side: BorderSide(color: palette.borderStrong),
          shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
          padding: const EdgeInsets.symmetric(horizontal: Gap.xxl),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: text.labelLarge,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: Gap.md),
          shape: const RoundedRectangleBorder(borderRadius: Radii.smAll),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: palette.textPrimary,
          minimumSize: const Size(44, 44),
          shape: const RoundedRectangleBorder(borderRadius: Radii.smAll),
        ),
      ),

      // -------------------------------------------------------------- inputs
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: isLight ? AppColors.neutral0 : scheme.surfaceContainer,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.lg,
        ),
        hintStyle: text.bodyLarge?.copyWith(color: palette.textTertiary),
        labelStyle: text.bodyMedium?.copyWith(color: palette.textSecondary),
        floatingLabelStyle: text.labelMedium?.copyWith(color: scheme.primary),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall?.copyWith(color: scheme.error),
        prefixIconColor: palette.textSecondary,
        suffixIconColor: palette.textSecondary,
        border: OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide(color: scheme.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide(color: scheme.error, width: 1.8),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide(color: palette.border.withValues(alpha: 0.5)),
        ),
      ),

      // --------------------------------------------------------------- chips
      chipTheme: ChipThemeData(
        backgroundColor: isLight ? AppColors.neutral0 : scheme.surfaceContainer,
        selectedColor: scheme.primaryContainer,
        disabledColor: palette.border,
        checkmarkColor: scheme.onPrimaryContainer,
        labelStyle: text.labelMedium!,
        secondaryLabelStyle: text.labelMedium!,
        side: BorderSide(color: palette.border),
        shape: const RoundedRectangleBorder(borderRadius: Radii.pillAll),
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.sm,
        ),
        showCheckmark: false,
        elevation: 0,
        pressElevation: 0,
      ),

      // ------------------------------------------------------------ surfaces
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: palette.surfaceElevated,
        modalBarrierColor: palette.overlay,
        shape: const RoundedRectangleBorder(borderRadius: Radii.sheet),
        showDragHandle: true,
        dragHandleColor: palette.borderStrong,
        dragHandleSize: const Size(40, 4),
        elevation: 0,
        modalElevation: 0,
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: Radii.xlAll),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: Gap.xxl,
          vertical: Gap.xxl,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.mdAll,
          side: BorderSide(color: palette.border),
        ),
        textStyle: text.bodyLarge,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
        insetPadding: const EdgeInsets.all(Gap.lg),
        elevation: 0,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: Radii.smAll,
        ),
        textStyle: text.bodySmall?.copyWith(color: scheme.onInverseSurface),
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.sm,
        ),
      ),

      // ----------------------------------------------------------- navigation
      navigationBarTheme: NavigationBarThemeData(
        height: Sizes.navBarHeight,
        backgroundColor: palette.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: Radii.pillAll,
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return text.labelSmall!.copyWith(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? scheme.primary : palette.textTertiary,
            letterSpacing: 0.1,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? scheme.onPrimaryContainer : palette.textTertiary,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: palette.surfaceElevated,
        indicatorColor: scheme.primaryContainer,
        selectedLabelTextStyle: text.labelMedium!.copyWith(
          color: scheme.primary,
        ),
        unselectedLabelTextStyle: text.labelMedium!.copyWith(
          color: palette.textTertiary,
        ),
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: palette.textTertiary),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: palette.textSecondary,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          borderRadius: Radii.smAll,
          color: scheme.primaryContainer,
        ),
        overlayColor: WidgetStatePropertyAll(
          scheme.primary.withValues(alpha: 0.06),
        ),
      ),

      // -------------------------------------------------------------- others
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.onPrimary;
          return isLight ? AppColors.neutral0 : AppColors.neutral300;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return palette.border;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return palette.borderStrong;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
        side: BorderSide(color: palette.borderStrong, width: 1.6),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(Radii.xs)),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return palette.borderStrong;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: palette.border,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        trackHeight: 5,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: palette.border,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 6,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.textSecondary,
        textColor: palette.textPrimary,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.xs,
        ),
        shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
        minVerticalPadding: Gap.md,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        highlightElevation: 4,
        shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(text.labelMedium),
          side: WidgetStatePropertyAll(BorderSide(color: palette.border)),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: Radii.mdAll),
          ),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
