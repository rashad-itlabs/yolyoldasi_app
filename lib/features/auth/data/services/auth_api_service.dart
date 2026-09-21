import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/otp_challenge.dart';
import '../models/auth_models.dart';

/// `/auth/*` — API.md §3.
class AuthApiService {
  const AuthApiService(this._client);

  final ApiClient _client;

  /// `POST /auth/phone/request` — public, 10 requests/minute per IP.
  ///
  /// [phone] is sent exactly as the user typed it; the server does the
  /// normalising and returns the canonical number to verify against.
  FutureResult<OtpChallenge> requestCode(String phone) => _client.post(
    Api.authPhoneRequest,
    body: {'phone': phone},
    parse: OtpChallengeModel.fromJson,
  );

  /// `POST /auth/phone/verify` — public, 20 requests/minute per IP.
  ///
  /// `device: "app"` is what makes the token non-expiring; `web` would expire
  /// it after an hour. `full_name`, `role` and `city_id` are deliberately not
  /// sent: they would overwrite an existing profile on every sign-in, and the
  /// setup screen collects them afterwards.
  FutureResult<AuthSession> verifyCode({
    required String phone,
    required String code,
    String? referralCode,
  }) => _client.post(
    Api.authPhoneVerify,
    body: {
      'phone': phone,
      'code': code,
      'device': 'app',
      // Only attaches on a brand-new account; the server ignores it otherwise
      // (API.md §21), so there is nothing to check here.
      'referral_code': ?referralCode,
    },
    parse: AuthSessionModel.fromJson,
  );

  /// `POST /auth/logout` — drops this device's token only.
  FutureResult<void> logout() => _client.send('POST', Api.authLogout);

  /// `DELETE /auth/account` — soft-deletes the account, anonymises the phone
  /// number and revokes every token. Irreversible (API.md §3).
  FutureResult<void> deleteAccount() => _client.send('DELETE', Api.authAccount);
}
