import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/app_update.dart';
import '../models/app_update_model.dart';

/// `GET /app-version` — API.md §17. Public, so it works before sign-in.
class AppUpdateApiService {
  const AppUpdateApiService(this._client);

  final ApiClient _client;

  /// [build] is what the server compares; [version] and [languageCode] only
  /// shape what it sends back to display.
  FutureResult<AppUpdate> check({
    required String platform,
    required int build,
    required String version,
    required String languageCode,
  }) {
    return _client.getObject(
      Api.appVersion,
      query: {
        'platform': platform,
        'build': build,
        'version': version,
        'lang': languageCode,
      },
      parse: AppUpdateModel.fromJson,
    );
  }
}
