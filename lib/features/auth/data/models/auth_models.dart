import '../../../../core/network/json_reader.dart';
import '../../../../core/types.dart';
import '../../../profile/domain/entities/user_enums.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/otp_challenge.dart';

/// `POST /auth/phone/request` — API.md §3.
///
/// ```json
/// { "message": "Təsdiq kodu yaradıldı.", "phone": "+994505550002",
///   "expires_in": 300, "resend_after": 60, "code": "752082" }
/// ```
abstract final class OtpChallengeModel {
  /// The fallbacks match the server's own defaults, so a response that omits
  /// them still drives a sensible countdown rather than a zero one.
  static OtpChallenge fromJson(Json json) => OtpChallenge(
    phone: json.str('phone'),
    expiresIn: Duration(seconds: json.integer('expires_in', 300)),
    resendAfter: Duration(seconds: json.integer('resend_after', 60)),
    devCode: json.strOrNull('code'),
  );
}

/// `POST /auth/phone/verify` — API.md §3.
///
/// ```json
/// { "token": "9|ZD7nhf...", "user": { "id": 6, "full_name": "...",
///   "phone": "+994505550002", "active_mode": "passenger",
///   "has_driver_profile": false }, "is_new_user": false }
/// ```
///
/// `user` here is a summary, not the full `/me` profile — no city, no stats, no
/// notification preferences. That is why it becomes an [AuthSession] rather
/// than an `AppUser`: the session bloc reads `/me` straight after and owns the
/// complete profile from then on. `is_new_user` is not carried for the same
/// reason — `/me` answering with an incomplete profile is what routes a new
/// account to the setup screen, and that works whether or not this flag said so.
abstract final class AuthSessionModel {
  static AuthSession fromJson(Json json) {
    final user = json.child('user');
    return AuthSession(
      token: json.str('token'),
      userId: user.integer('id'),
      fullName: user.str('full_name'),
      phone: user.str('phone'),
      activeMode: UserMode.fromApi(user.strOrNull('active_mode')),
      hasDriverProfile: user.flag('has_driver_profile'),
    );
  }
}
