import '../../../../core/error/result.dart';
import '../../../../core/network/upload_file.dart';
import '../entities/app_user.dart';
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

  FutureResult<NotificationPreferences> notificationPreferences();

  FutureResult<NotificationPreferences> saveNotificationPreferences(
    NotificationPreferences preferences,
  );

  /// `POST /me/device-tokens`. Called after sign-in, on `onTokenRefresh` and
  /// on every launch.
  FutureResult<void> registerDeviceToken({
    required String token,
    required DevicePlatform platform,
  });

  /// `DELETE /me/device-tokens`. Call before signing out.
  FutureResult<void> unregisterDeviceToken(String token);
}
