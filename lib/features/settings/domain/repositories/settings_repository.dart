import 'package:flutter/material.dart' show ThemeMode;

/// Device-local preferences.
///
/// Deliberately small: recent searches now live on the server
/// (`GET /me/recent-searches`) and the language is part of the account
/// (`language_code` on `/me`), so the only things left here are the ones that
/// genuinely belong to the handset and must be readable before the first frame.
abstract interface class SettingsRepository {
  /// Must be awaited once during bootstrap — the synchronous getters below
  /// read from the cache it fills, which is what keeps the app from flashing
  /// the wrong theme.
  Future<void> load();

  ThemeMode get themeMode;
  Future<void> setThemeMode(ThemeMode mode);

  /// The language to render before `/me` has answered, and the override for a
  /// signed-out user. `null` means "follow the device locale".
  String? get languageCode;
  Future<void> setLanguageCode(String? code);

  bool get onboardingSeen;
  Future<void> setOnboardingSeen(bool seen);

  /// Clears everything except [onboardingSeen] — a user who signs out has
  /// still seen the intro.
  Future<void> clearForSignOut();
}
