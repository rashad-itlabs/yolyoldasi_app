part of 'settings_bloc.dart';

class SettingsState extends Equatable {
  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.languageCode,
    this.syncedUser,
  });

  final ThemeMode themeMode;

  /// `null` means "follow the device locale".
  final String? languageCode;

  /// The profile returned by the `PATCH /me` that carried a language change,
  /// so the settings screen can hand it back to [SessionBloc].
  final AppUser? syncedUser;

  SettingsState copyWith({
    ThemeMode? themeMode,
    String? Function()? languageCode,
    AppUser? Function()? syncedUser,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      languageCode: languageCode != null ? languageCode() : this.languageCode,
      syncedUser: syncedUser != null ? syncedUser() : this.syncedUser,
    );
  }

  @override
  List<Object?> get props => [themeMode, languageCode, syncedUser];
}
