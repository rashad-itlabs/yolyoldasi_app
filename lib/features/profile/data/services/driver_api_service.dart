import 'package:dio/dio.dart';

import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/upload_file.dart';
import '../../domain/entities/driver_profile.dart';
import '../../domain/entities/user_enums.dart';
import '../models/driver_profile_model.dart';

/// `/driver/*` — API.md §7.
class DriverApiService {
  const DriverApiService(this._client);

  final ApiClient _client;

  /// `GET /driver/profile`
  FutureResult<DriverProfile> profile() =>
      _client.getObject(Api.driverProfile, parse: DriverProfileModel.fromJson);

  /// `PUT /driver/profile` — only `instant_booking_default` is editable.
  FutureResult<DriverProfile> setInstantBookingDefault(bool value) =>
      _client.put(
        Api.driverProfile,
        body: {'instant_booking_default': value},
        parse: DriverProfileModel.fromJson,
      );

  /// `POST /driver/documents` — multipart, jpg/jpeg/png/pdf, ≤8 MB.
  ///
  /// Re-uploading replaces the stored document and sends it back to `pending`,
  /// which is also how a rejected document is resubmitted. Sending [backFile]
  /// for a type that has no back side is a 422, so the caller is expected to
  /// check [DocumentType.requiresBackSide] first.
  ///
  /// API.md does not pin down the 201 body, so nothing is parsed out of it —
  /// the repository re-reads the profile, which also picks up the aggregate
  /// `status` the upload just changed.
  FutureResult<void> uploadDocument({
    required DocumentType type,
    required UploadFile file,
    UploadFile? backFile,
  }) {
    final form = FormData.fromMap({
      'type': type.apiValue,
      'file': file.toMultipart(),
      if (backFile != null) 'back_file': backFile.toMultipart(),
    });
    return _client.upload<void>(Api.driverDocuments, form: form, parse: (_) {});
  }
}
