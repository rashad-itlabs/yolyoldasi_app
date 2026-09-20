import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/layout_size.dart';
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

  /// How much room this screen has — see [LayoutSize].
  ///
  /// Measured on the shortest side, so a phone held sideways stays compact
  /// rather than being mistaken for a tablet.
  LayoutSize get layout => LayoutSize.of(this);

  bool get isCompact => layout.isCompact;
  bool get isTablet => layout.isTablet;

  /// Widest the content column gets here, and the padding around it.
  double get contentMaxWidth => layout.contentWidth;
  double get pagePadding => layout.pagePadding;

  /// Extra side padding that pulls a full-bleed page into the content column.
  ///
  /// Zero on a phone. For a screen that paints edge to edge on purpose — a
  /// gradient header, a hero image — adding this to the horizontal padding
  /// keeps the backdrop full width while the text and cards on top of it line
  /// up with the column every other screen uses.
  double get columnInset =>
      ((screenWidth - contentMaxWidth) / 2).clamp(0.0, double.infinity);

  /// Dismisses the keyboard without unfocusing programmatic focus traps.
  void hideKeyboard() => FocusScope.of(this).unfocus();
}
