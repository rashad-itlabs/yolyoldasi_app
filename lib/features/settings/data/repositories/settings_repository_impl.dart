import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../profile/domain/entities/user_enums.dart';
import '../../domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;

  ThemeMode _themeMode = ThemeMode.system;
  String? _languageCode;
  bool _onboardingSeen = false;
  String? _dismissedUpdateVersion;

  @override
  Future<void> load() async {
    _themeMode = _readThemeMode();
    final code = _prefs.getString(PrefKeys.languageCode);
    _languageCode = AppLanguages.isSupported(code) ? code : null;
    _onboardingSeen = _prefs.getBool(PrefKeys.onboardingSeen) ?? false;
    _dismissedUpdateVersion = _prefs.getString(PrefKeys.dismissedUpdate);
  }

  ThemeMode _readThemeMode() {
    final stored = _prefs.getString(PrefKeys.themeMode);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  @override
  ThemeMode get themeMode => _themeMode;

  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setString(PrefKeys.themeMode, mode.name);
  }

  @override
  String? get languageCode => _languageCode;

  @override
  Future<void> setLanguageCode(String? code) async {
    final normalized = AppLanguages.isSupported(code) ? code : null;
    _languageCode = normalized;
    if (normalized == null) {
      await _prefs.remove(PrefKeys.languageCode);
    } else {
      await _prefs.setString(PrefKeys.languageCode, normalized);
    }
  }

  @override
  bool get onboardingSeen => _onboardingSeen;

  @override
  Future<void> setOnboardingSeen(bool seen) async {
    _onboardingSeen = seen;
    await _prefs.setBool(PrefKeys.onboardingSeen, seen);
  }

  @override
  String? get dismissedUpdateVersion => _dismissedUpdateVersion;

  @override
  Future<void> setDismissedUpdateVersion(String? version) async {
    _dismissedUpdateVersion = version;
    if (version == null) {
      await _prefs.remove(PrefKeys.dismissedUpdate);
    } else {
      await _prefs.setString(PrefKeys.dismissedUpdate, version);
    }
  }

  @override
  Future<void> clearForSignOut() async {
    // The theme is a device preference and survives, as does the dismissed
    // update — which build this phone has is not a fact about who is signed
    // in. The language does not, because the next account carries its own
    // `language_code`.
    _languageCode = null;
    await _prefs.remove(PrefKeys.languageCode);
  }
}
