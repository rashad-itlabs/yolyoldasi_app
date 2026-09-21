import '../../../../core/error/result.dart';
import '../../../../core/network/upload_file.dart';
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
  }) : _users = users,
       _deviceTokens = deviceTokens;

  final UserApiService _users;
  final DeviceTokenApiService _deviceTokens;

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
  FutureResult<AppUser> uploadPhoto(UploadFile photo) =>
      _users.uploadPhoto(photo);

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
