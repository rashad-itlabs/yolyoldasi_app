import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../../../../../core/error/result.dart';
import '../../../../profile/domain/entities/app_user.dart';
import '../../../../profile/domain/entities/user_enums.dart';
import '../../../../profile/domain/repositories/user_repository.dart';
import '../../../domain/repositories/settings_repository.dart';

part 'settings_event.dart';
part 'settings_state.dart';

/// Theme and language.
///
/// The theme is device-local. The language is both: `language_code` belongs to
/// the account (API.md §4), but it also has to be readable before `/me`
/// answers and while signed out, so it is mirrored into preferences and pushed
/// to the server when it changes.
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc({
    required SettingsRepository settings,
    required UserRepository users,
  }) : _settings = settings,
       _users = users,
       super(const SettingsState()) {
    on<SettingsStarted>(_onStarted);
    on<SettingsThemeChanged>(_onThemeChanged);
    on<SettingsLanguageChanged>(_onLanguageChanged);
    on<SettingsLanguageSynced>(_onLanguageSynced);
  }

  final SettingsRepository _settings;
  final UserRepository _users;

  void _onStarted(SettingsStarted event, Emitter<SettingsState> emit) {
    emit(
      SettingsState(
        themeMode: _settings.themeMode,
        languageCode: _settings.languageCode,
      ),
    );
  }

  Future<void> _onThemeChanged(
    SettingsThemeChanged event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(themeMode: event.mode));
    await _settings.setThemeMode(event.mode);
  }

  Future<void> _onLanguageChanged(
    SettingsLanguageChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final code = event.languageCode;
    emit(state.copyWith(languageCode: () => code));
    await _settings.setLanguageCode(code);

    // "Follow the device" has no server equivalent, so only an explicit choice
    // is pushed. A failure is silent: the app is already showing the new
    // language, and the next `PATCH /me` will carry it.
    if (code != null && event.persistToAccount) {
      final result = await _users.updateProfile(languageCode: code);
      if (result case Ok(:final value)) {
        emit(state.copyWith(syncedUser: () => value));
      }
    }
  }

  /// Adopts the language from a freshly-loaded profile, so an account that
  /// chose Russian on another device opens in Russian here too.
  Future<void> _onLanguageSynced(
    SettingsLanguageSynced event,
    Emitter<SettingsState> emit,
  ) async {
    final code = AppLanguages.normalize(event.languageCode);
    if (state.languageCode == code) return;
    emit(state.copyWith(languageCode: () => code));
    await _settings.setLanguageCode(code);
  }
}
