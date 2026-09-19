import '../../../../core/network/json_reader.dart';
import '../../../../core/types.dart';
import '../../domain/entities/driver_profile.dart';
import '../../domain/entities/user_enums.dart';
import 'vehicle_model.dart';

/// `GET /driver/profile` (API.md §7).
abstract final class DriverProfileModel {
  static DriverProfile fromJson(Json json) {
    return DriverProfile(
      status: VerificationStatus.fromApi(json.strOrNull('status')),
      documents: _documents(json.children('documents')),
      vehicle: VehicleModel.fromJsonOrNull(json.childOrNull('vehicle')),
      submittedAt: json.dateOrNull('submitted_at'),
      reviewedAt: json.dateOrNull('reviewed_at'),
      rejectionReason: json.strOrNull('rejection_reason'),
      instantBookingDefault: json.flag('instant_booking_default'),
    );
  }

  /// API.md §7 promises all four documents on every read, but the screen is
  /// built on that promise, so any type the response omitted is filled in as
  /// `not_uploaded` rather than leaving a hole in the list.
  static List<VerificationDocument> _documents(List<Json> raw) {
    final parsed = <DocumentType, VerificationDocument>{};
    for (final json in raw) {
      final document = _document(json);
      parsed[document.type] = document;
    }
    return [
      for (final type in DocumentType.values)
        parsed[type] ?? VerificationDocument.empty(type),
    ];
  }

  static VerificationDocument _document(Json json) {
    final type = DocumentType.fromApi(json.strOrNull('type'));
    return VerificationDocument(
      type: type,
      status: VerificationStatus.fromApi(json.strOrNull('status')),
      uploadedAt: json.dateOrNull('uploaded_at'),
      rejectionReason: json.strOrNull('rejection_reason'),
      needsBackSide: json.containsKey('needs_back_side')
          ? json.flag('needs_back_side')
          : null,
    );
  }
}
