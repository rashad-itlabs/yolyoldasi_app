import '../../../../core/error/result.dart';
import '../../../../core/services/app_version_info.dart';
import '../../../profile/domain/entities/user_enums.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../../domain/entities/app_update.dart';
import '../../domain/repositories/app_update_repository.dart';
import '../services/app_update_api_service.dart';

class AppUpdateRepositoryImpl implements AppUpdateRepository {
  AppUpdateRepositoryImpl({
    required AppUpdateApiService api,
    required AppVersionInfo version,
    required SettingsRepository settings,
  }) : _api = api,
       _version = version,
       _settings = settings;

  final AppUpdateApiService _api;
  final AppVersionInfo _version;
  final SettingsRepository _settings;

  @override
  FutureResult<AppUpdate> check() {
    // A build that could not say what it is cannot be judged, so it is not
    // asked about. Only happens where the platform channel is missing — a
    // widget test, mainly — and the alternative would be sending `build=0`,
    // which is below every conceivable minimum.
    if (!_version.isKnown) return Future.value(const Ok(AppUpdate.none));

    return _api.check(
      platform: DevicePlatform.current.apiValue,
      build: _version.build,
      version: _version.version,
      // Whatever language the app is rendering in. After a first sign-in this
      // is the account's own `language_code`, which the settings bloc writes
      // through on every launch; before that it is the device preference, or
      // Azerbaijani. The server falls back to Azerbaijani for anything it has
      // no translation of, so a wrong guess still produces a readable screen.
      languageCode: AppLanguages.normalize(_settings.languageCode),
    );
  }
}
