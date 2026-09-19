part of 'settings_bloc.dart';

sealed class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => const [];
}

/// Reads the persisted preferences. Fired once, during boot.
class SettingsStarted extends SettingsEvent {
  const SettingsStarted();
}

class SettingsThemeChanged extends SettingsEvent {
  const SettingsThemeChanged(this.mode);

  final ThemeMode mode;

  @override
  List<Object?> get props => [mode];
}

class SettingsLanguageChanged extends SettingsEvent {
  const SettingsLanguageChanged(
    this.languageCode, {
    this.persistToAccount = true,
  });

  /// `null` means "follow the device locale".
  final String? languageCode;

  /// Whether to also write it to `language_code` on the account. False while
  /// signed out, where there is no account to write to.
  final bool persistToAccount;

  @override
  List<Object?> get props => [languageCode, persistToAccount];
}

/// Adopts the `language_code` from a profile that has just loaded.
class SettingsLanguageSynced extends SettingsEvent {
  const SettingsLanguageSynced(this.languageCode);

  final String languageCode;

  @override
  List<Object?> get props => [languageCode];
}
