import 'package:dio/dio.dart';

import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/upload_file.dart';
import '../../../../core/types.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_enums.dart';
import '../models/user_model.dart';

/// `/me` and `/users/{id}` — API.md §4 and §12.
class UserApiService {
  const UserApiService(this._client);

  final ApiClient _client;

  /// `GET /me`
  FutureResult<AppUser> me() =>
      _client.getObject(Api.me, parse: UserModel.fromJson);

  /// `PATCH /me` — only the fields passed are sent.
  FutureResult<AppUser> updateMe(Json body) =>
      _client.patch(Api.me, body: body, parse: UserModel.fromJson);

  /// `PUT /me/mode` — 422 when the account has no driver profile.
  FutureResult<AppUser> setActiveMode(UserMode mode) => _client.put(
    Api.meMode,
    body: {'active_mode': mode.apiValue},
    parse: UserModel.fromJson,
  );

  /// `POST /me/photo` — multipart, jpg/jpeg/png/webp, ≤4 MB. The old photo is
  /// deleted server-side.
  FutureResult<AppUser> uploadPhoto(UploadFile photo) {
    final form = FormData.fromMap({'photo': photo.toMultipart()});
    return _client.upload(Api.mePhoto, form: form, parse: UserModel.fromJson);
  }

  /// `GET /users/{id}` — the public profile of somebody else.
  FutureResult<PublicUser> publicProfile(int userId) =>
      _client.getObject(Api.user(userId), parse: PublicUserModel.fromJson);

  /// `GET /me/notification-preferences`
  FutureResult<NotificationPreferences> notificationPreferences() =>
      _client.getObject(
        Api.meNotificationPreferences,
        parse: NotificationPreferencesModel.fromJson,
      );

  /// `PUT /me/notification-preferences`
  FutureResult<NotificationPreferences> saveNotificationPreferences(
    NotificationPreferences prefs,
  ) => _client.put(
    Api.meNotificationPreferences,
    body: NotificationPreferencesModel.toJson(prefs),
    parse: NotificationPreferencesModel.fromJson,
  );
}
