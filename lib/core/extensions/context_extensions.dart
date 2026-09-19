import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/app_colors.dart';
import '../utils/app_format.dart';

/// Shorthands used across every widget in the app.
extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;

  /// Semantic colours that Material's scheme does not cover.
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Localized strings — `context.l10n.bookSeat`.
  AppStrings get l10n => AppLocalizations.of(this);

  /// Locale-aware formatting — `context.fmt.price(15)`.
  AppFormat get fmt => AppFormat(AppLocalizations.of(this));

  MediaQueryData get mq => MediaQuery.of(this);
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Safe-area insets, most often needed for bottom action bars.
  EdgeInsets get viewPadding => MediaQuery.viewPaddingOf(this);
  double get bottomSafeArea => MediaQuery.viewPaddingOf(this).bottom;

  /// Height of the on-screen keyboard, 0 when it is closed.
  double get keyboardHeight => MediaQuery.viewInsetsOf(this).bottom;
  bool get isKeyboardOpen => keyboardHeight > 0;

  /// Layout breakpoints. Phones stay single column; the admin panel and
  /// tablets get the wide treatment.
  bool get isCompact => screenWidth < 600;
  bool get isMedium => screenWidth >= 600 && screenWidth < 1024;
  bool get isExpanded => screenWidth >= 1024;

  /// Dismisses the keyboard without unfocusing programmatic focus traps.
  void hideKeyboard() => FocusScope.of(this).unfocus();
}
