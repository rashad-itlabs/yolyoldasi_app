import '../../../../core/config/app_config.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/services/token_storage.dart';
import '../../../profile/data/services/device_token_api_service.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/otp_challenge.dart';
import '../../domain/repositories/auth_repository.dart';
import '../services/auth_api_service.dart';

/// Phone sign-in over the two `/auth/phone/*` endpoints (API.md §3).
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthApiService api,
    required DeviceTokenApiService deviceTokens,
    required TokenStorage tokens,
    required Stream<void> unauthorized,
  }) : _api = api,
       _deviceTokens = deviceTokens,
       _tokens = tokens,
       _unauthorized = unauthorized;

  final AuthApiService _api;
  final DeviceTokenApiService _deviceTokens;
  final TokenStorage _tokens;
  final Stream<void> _unauthorized;

  @override
  bool get hasSession => (_tokens.token ?? '').isNotEmpty;

  @override
  Stream<void> get onSessionExpired => _unauthorized;

  @override
  Future<bool> restoreSession() async {
    final token = await _tokens.restore();
    if (token != null && token.isNotEmpty) return true;

    // `--dart-define=DEV_API_TOKEN=...` starts a development build signed in,
    // skipping the SMS round trip against a live backend. It is adopted rather
    // than validated here: `GET /me` runs next either way, and a stale one
    // comes back 401 and signs the user straight out again.
    final preset = AppConfig.devApiToken;
    if (preset.isEmpty) return false;
    await _tokens.save(preset);
    return true;
  }

  @override
  FutureResult<OtpChallenge> requestCode(String phone) {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) {
      return Future.value(
        const Err(ValidationFailure(FailureCode.invalidInput, field: 'phone')),
      );
    }
    return _api.requestCode(trimmed);
  }

  @override
  FutureResult<AuthSession> verifyCode({
    required String phone,
    required String code,
  }) async {
    final result = await _api.verifyCode(phone: phone, code: code.trim());

    if (result case Ok(:final value)) {
      // Nothing is stored until the API has issued a token, so a failed verify
      // leaves the previous state — signed out — exactly as it was.
      await _tokens.save(value.token);
    }
    return result;
  }

  @override
  FutureResult<void> logout({String? deviceToken}) async {
    await _releaseDeviceToken(deviceToken);

    // The local session is dropped whatever the API says: a failed logout must
    // not leave the user stuck in an account they asked to leave.
    final result = await _api.logout();
    await clearSession();
    return result;
  }

  @override
  FutureResult<void> deleteAccount({String? deviceToken}) async {
    await _releaseDeviceToken(deviceToken);

    final result = await _api.deleteAccount();
    if (result case Err(:final failure)) return Err(failure);

    await clearSession();
    return const Ok(null);
  }

  /// Best-effort: a failure here is not worth blocking a sign-out over, and the
  /// server drops the token with the account anyway.
  Future<void> _releaseDeviceToken(String? deviceToken) async {
    if (deviceToken == null || deviceToken.isEmpty) return;
    await _deviceTokens.unregister(deviceToken);
  }

  @override
  Future<void> clearSession() => _tokens.clear();
}
