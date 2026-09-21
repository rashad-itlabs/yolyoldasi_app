import '../../../../core/network/json_reader.dart';
import '../../../../core/types.dart';
import '../../domain/entities/app_update.dart';

/// ```json
/// { "status": "required", "min_version": "1.1.0", "min_build": 8,
///   "latest_version": "1.2.0", "latest_build": 12,
///   "store_url": "https://…", "message": "…" }
/// ```
///
/// An `ok` answer carries nothing but the status, so every other key is read
/// as optional.
abstract final class AppUpdateModel {
  static AppUpdate fromJson(Json json) => AppUpdate(
    status: _status(json.str('status')),
    latestVersion: json.strOrNull('latest_version'),
    minVersion: json.strOrNull('min_version'),
    storeUrl: json.strOrNull('store_url'),
    message: json.strOrNull('message'),
  );

  /// An unrecognised status is treated as "nothing to do".
  ///
  /// This is the one parse decision worth stating out loud. If a future
  /// server grows a fourth status, an old build should carry on working
  /// rather than lock its user out over a word it does not know.
  static AppUpdateStatus _status(String raw) => switch (raw) {
    'required' => AppUpdateStatus.forced,
    'optional' => AppUpdateStatus.optional,
    _ => AppUpdateStatus.none,
  };
}
