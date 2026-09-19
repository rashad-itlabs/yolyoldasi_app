import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/user_enums.dart';

/// `/me/device-tokens` — API.md §5.
class DeviceTokenApiService {
  const DeviceTokenApiService(this._client);

  final ApiClient _client;

  /// `POST /me/device-tokens`
  ///
  /// The server does `updateOrCreate`, so re-sending the same token is safe —
  /// which is what makes "call it on every launch" the recommended usage.
  FutureResult<void> register({
    required String token,
    required DevicePlatform platform,
  }) => _client.send(
    'POST',
    Api.meDeviceTokens,
    body: {'token': token, 'platform': platform.apiValue},
  );

  /// `DELETE /me/device-tokens`
  ///
  /// Must run **before** logout, or the device keeps receiving the previous
  /// account's notifications (API.md §5).
  FutureResult<void> unregister(String token) =>
      _client.send('DELETE', Api.meDeviceTokens, body: {'token': token});
}
