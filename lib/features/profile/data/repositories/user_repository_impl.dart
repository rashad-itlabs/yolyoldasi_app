import '../../../../core/error/result.dart';
import '../../../../core/network/media_url.dart';
import '../../../../core/network/upload_file.dart';
import '../../../../core/services/image_cache_seeder.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/referral.dart';
import '../../domain/entities/user_enums.dart';
import '../../domain/repositories/user_repository.dart';
import '../models/user_model.dart';
import '../services/device_token_api_service.dart';
import '../services/user_api_service.dart';

class UserRepositoryImpl implements UserRepository {
  const UserRepositoryImpl({
    required UserApiService users,
    required DeviceTokenApiService deviceTokens,
    ImageCacheSeeder? imageCache,
  }) : _users = users,
       _deviceTokens = deviceTokens,
       _imageCache = imageCache ?? const CachedImageSeeder();

  final UserApiService _users;
  final DeviceTokenApiService _deviceTokens;
  final ImageCacheSeeder _imageCache;

  @override
  FutureResult<AppUser> me() => _users.me();

  @override
  FutureResult<AppUser> updateProfile({
    String? fullName,
    String? Function()? about,
    Gender? gender,
    int? Function()? birthYear,
    int? Function()? cityId,
    String? languageCode,
  }) {
    final body = UserModel.patchBody(
      fullName: fullName,
      about: about,
      gender: gender,
      birthYear: birthYear,
      cityId: cityId,
      languageCode: languageCode,
    );
    // An empty PATCH would be a pointless round trip; answer with the current
    // profile instead so the caller's success path still gets a user.
    if (body.isEmpty) return me();
    return _users.updateMe(body);
  }

  @override
  FutureResult<AppUser> setActiveMode(UserMode mode) =>
      _users.setActiveMode(mode);

  @override
  FutureResult<AppUser> uploadPhoto(UploadFile photo) async {
    final result = await _users.uploadPhoto(photo);

    // The phone already has these bytes; the server only gave them a new URL.
    // Seeded before returning, so the first avatar that rebuilds with the new
    // URL finds it on disk instead of downloading it back.
    final url = result.valueOrNull?.photoUrl;
    if (url != null && url.isNotEmpty) {
      try {
        await _imageCache.seed(
          MediaUrl.resolve(url),
          photo.bytes,
          fileExtension: _extensionOf(photo.fileName),
        );
      } catch (_) {
        // A cache that cannot be written only costs a download; the upload
        // itself has succeeded and must be reported as such.
      }
    }
    return result;
  }

  static String _extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot == -1 ? 'jpg' : fileName.substring(dot + 1).toLowerCase();
  }

  @override
  FutureResult<ReferralSummary> referral() => _users.referral();

  @override
  FutureResult<PublicUser> publicProfile(int userId) =>
      _users.publicProfile(userId);

  @override
  FutureResult<NotificationPreferences> notificationPreferences() =>
      _users.notificationPreferences();

  @override
  FutureResult<NotificationPreferences> saveNotificationPreferences(
    NotificationPreferences preferences,
  ) => _users.saveNotificationPreferences(preferences);

  @override
  FutureResult<void> registerDeviceToken({
    required String token,
    required DevicePlatform platform,
    String? provider,
    String? externalId,
  }) => _deviceTokens.register(
    token: token,
    platform: platform,
    provider: provider,
    externalId: externalId,
  );

  @override
  FutureResult<void> unregisterDeviceToken(String token) =>
      _deviceTokens.unregister(token);
}
