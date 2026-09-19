import '../../../../core/error/result.dart';
import '../entities/auth_session.dart';
import '../entities/otp_challenge.dart';

/// Owns the session: obtaining a Sanctum token and letting go of it.
///
/// Sign-in is the two-step phone flow in API.md §3 — ask for a code, then trade
/// the code for a token. Both steps are public; neither needs a session.
///
/// Profile data lives in `UserRepository` — this is deliberately narrow.
abstract interface class AuthRepository {
  /// Whether a Sanctum token is loaded. `true` does not guarantee the token is
  /// still valid; the first call that returns 401 settles that.
  bool get hasSession;

  /// Emits when the API rejects the stored token. The session bloc listens and
  /// signs the user out (API.md §16.2).
  Stream<void> get onSessionExpired;

  /// Reads the persisted token into memory. Runs once during boot, before the
  /// first request.
  Future<bool> restoreSession();

  /// `POST /auth/phone/request` — issues a code for [phone].
  ///
  /// [phone] goes up as typed; the server normalises it and the returned
  /// [OtpChallenge.phone] is what [verifyCode] must be given.
  ///
  /// Fails with [ValidationFailure] on a malformed number and
  /// [RateLimitFailure] when another code was asked for too soon.
  FutureResult<OtpChallenge> requestCode(String phone);

  /// `POST /auth/phone/verify` — trades a code for a session.
  ///
  /// [phone] must be the canonical number from [requestCode], not the user's
  /// original input.
  ///
  /// Fails with [ValidationFailure] on a wrong, expired or already-used code,
  /// [RateLimitFailure] after five wrong attempts (which cancels the code), and
  /// [PermissionFailure] when the account is blocked.
  FutureResult<AuthSession> verifyCode({
    required String phone,
    required String code,
  });

  /// `POST /auth/logout`, then clears the local token.
  ///
  /// [deviceToken] is unregistered first when there is one (API.md §5). There
  /// is no push provider in this build, so it is normally absent.
  FutureResult<void> logout({String? deviceToken});

  /// `DELETE /auth/account`. Irreversible — confirm with the user first.
  FutureResult<void> deleteAccount({String? deviceToken});

  /// Drops the local session without calling the API. Used when the API has
  /// already told us the token is dead.
  Future<void> clearSession();
}
