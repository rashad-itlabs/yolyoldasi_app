import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_constants.dart';
import 'user_enums.dart';
import 'vehicle.dart';

/// One of the four documents in `GET /driver/profile` (API.md §7).
///
/// The API returns metadata only — there is no URL to the uploaded file, so the
/// UI shows status rather than a preview.
class VerificationDocument extends Equatable {
  const VerificationDocument({
    required this.type,
    required this.status,
    this.uploadedAt,
    this.rejectionReason,
    bool? needsBackSide,
  }) : _needsBackSide = needsBackSide;

  final DocumentType type;
  final VerificationStatus status;
  final DateTime? uploadedAt;
  final String? rejectionReason;

  /// The server's own answer, when it sent one. Falls back to the rule in
  /// API.md §7 — only the ID card and the licence are two-sided.
  final bool? _needsBackSide;

  bool get needsBackSide => _needsBackSide ?? type.requiresBackSide;

  factory VerificationDocument.empty(DocumentType type) =>
      VerificationDocument(type: type, status: VerificationStatus.notUploaded);

  bool get isUploaded => status != VerificationStatus.notUploaded;
  bool get isApproved => status.isApproved;
  bool get isRejected => status.isRejected;

  /// Whether the documents screen should invite a (re-)upload. A rejected
  /// document is re-sent through the same endpoint (API.md §7).
  bool get needsAction => status.isNotUploaded || status.isRejected;

  VerificationDocument copyWith({
    VerificationStatus? status,
    DateTime? Function()? uploadedAt,
    String? Function()? rejectionReason,
  }) {
    return VerificationDocument(
      type: type,
      status: status ?? this.status,
      uploadedAt: uploadedAt != null ? uploadedAt() : this.uploadedAt,
      rejectionReason: rejectionReason != null
          ? rejectionReason()
          : this.rejectionReason,
      needsBackSide: _needsBackSide,
    );
  }

  @override
  List<Object?> get props => [
    type,
    status,
    uploadedAt,
    rejectionReason,
    needsBackSide,
  ];
}

/// `GET /driver/profile` (API.md §7): verification state plus the car the
/// driver publishes with.
class DriverProfile extends Equatable {
  const DriverProfile({
    required this.status,
    required this.documents,
    this.vehicle,
    this.submittedAt,
    this.reviewedAt,
    this.rejectionReason,
    this.instantBookingDefault = false,
  });

  /// Derived by the server from the four documents (API.md §7): all approved →
  /// `approved`; any rejected → `rejected`; all uploaded → `pending`;
  /// otherwise `not_uploaded`.
  final VerificationStatus status;

  /// Always four entries, one per [DocumentType], in the order the API sent
  /// them. Missing types are filled in as `not_uploaded` so the screen can
  /// render the list without checking for holes.
  final List<VerificationDocument> documents;

  /// `null` until the driver adds their first car.
  final Vehicle? vehicle;

  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? rejectionReason;

  /// Pre-fills `instant_booking` on new rides. Editing it does not touch rides
  /// already published (API.md §7).
  final bool instantBookingDefault;

  /// The state a user who has never started driver onboarding is in.
  static final DriverProfile initial = DriverProfile(
    status: VerificationStatus.notUploaded,
    documents: [
      for (final type in DocumentType.values) VerificationDocument.empty(type),
    ],
  );

  VerificationDocument documentOf(DocumentType type) => documents.firstWhere(
    (d) => d.type == type,
    orElse: () => VerificationDocument.empty(type),
  );

  int get uploadedDocumentCount => documents.where((d) => d.isUploaded).length;

  int get approvedDocumentCount => documents.where((d) => d.isApproved).length;

  bool get allDocumentsUploaded =>
      uploadedDocumentCount >= AppRules.requiredDocumentCount;

  List<VerificationDocument> get rejectedDocuments =>
      documents.where((d) => d.isRejected).toList(growable: false);

  bool get hasVehicle => vehicle != null;

  /// Everything is in: the car is saved and all four documents are uploaded.
  bool get canSubmitForReview => hasVehicle && allDocumentsUploaded;

  /// The gate the publish flow checks: a car, and all four documents approved
  /// by an admin (API.md §9). The server refuses `POST /rides` and
  /// `/rides/{id}/repeat` otherwise; this only keeps the driver from filling
  /// in a three-step form to be told so at the end.
  ///
  /// Rides already published before the rule are left alone.
  bool get canPublishRides => hasVehicle && status.isApproved;

  /// Whether the driver still has verification work to do — or is waiting on
  /// it. Drives the banner that explains why publishing is locked.
  bool get needsVerification => !status.isApproved;

  /// 0–1, for the onboarding progress bar.
  double get completionFraction =>
      uploadedDocumentCount / AppRules.requiredDocumentCount;

  DriverProfile copyWith({
    VerificationStatus? status,
    List<VerificationDocument>? documents,
    Vehicle? Function()? vehicle,
    DateTime? Function()? submittedAt,
    DateTime? Function()? reviewedAt,
    String? Function()? rejectionReason,
    bool? instantBookingDefault,
  }) {
    return DriverProfile(
      status: status ?? this.status,
      documents: documents ?? this.documents,
      vehicle: vehicle != null ? vehicle() : this.vehicle,
      submittedAt: submittedAt != null ? submittedAt() : this.submittedAt,
      reviewedAt: reviewedAt != null ? reviewedAt() : this.reviewedAt,
      rejectionReason: rejectionReason != null
          ? rejectionReason()
          : this.rejectionReason,
      instantBookingDefault:
          instantBookingDefault ?? this.instantBookingDefault,
    );
  }

  @override
  List<Object?> get props => [
    status,
    documents,
    vehicle,
    submittedAt,
    reviewedAt,
    rejectionReason,
    instantBookingDefault,
  ];
}
