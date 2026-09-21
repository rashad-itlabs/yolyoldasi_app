import '../../../../core/error/result.dart';
import '../../../../core/network/upload_file.dart';
import '../entities/app_user.dart';
import '../entities/referral.dart';
import '../entities/user_enums.dart';

/// The signed-in account and other people's public profiles.
abstract interface class UserRepository {
  /// `GET /me`.
  FutureResult<AppUser> me();

  /// `PATCH /me`. Every parameter is optional; the nullable ones are wrapped in
  /// a closure so passing `() => null` clears the field while omitting the
  /// argument leaves it alone.
  FutureResult<AppUser> updateProfile({
    String? fullName,
    String? Function()? about,
    Gender? gender,
    int? Function()? birthYear,
    int? Function()? cityId,
    String? languageCode,
  });

  /// `PUT /me/mode`. Fails with a 422 when switching to `driver` on an account
  /// that has no driver profile.
  FutureResult<AppUser> setActiveMode(UserMode mode);

  /// `POST /me/photo`.
  FutureResult<AppUser> uploadPhoto(UploadFile photo);

  /// `GET /users/{id}`.
  FutureResult<PublicUser> publicProfile(int userId);

  /// `GET /me/referral` — the invite code and what it has earned so far.
  FutureResult<ReferralSummary> referral();

  FutureResult<NotificationPreferences> notificationPreferences();

  FutureResult<NotificationPreferences> saveNotificationPreferences(
    NotificationPreferences preferences,
  );

  /// `POST /me/device-tokens`. Called after sign-in, whenever the subscription
  /// rotates, and on every launch.
  ///
  /// [provider] names the transport that issued [token] — the server cannot
  /// tell an FCM registration token from a OneSignal subscription id by shape,
  /// and it reaches them through different APIs. [externalId] is the account
  /// alias the device was logged in under, which is how the server addresses
  /// the *user* rather than chasing their individual devices.
  FutureResult<void> registerDeviceToken({
    required String token,
    required DevicePlatform platform,
    String? provider,
    String? externalId,
  });

  /// `DELETE /me/device-tokens`. Call before signing out.
  FutureResult<void> unregisterDeviceToken(String token);
}
