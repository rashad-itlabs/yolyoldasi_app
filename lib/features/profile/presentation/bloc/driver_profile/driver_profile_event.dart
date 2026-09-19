part of 'driver_profile_bloc.dart';

sealed class DriverProfileEvent extends Equatable {
  const DriverProfileEvent();

  @override
  List<Object?> get props => const [];
}

/// `GET /driver/profile`. Safe to fire on every screen entry.
class DriverProfileRequested extends DriverProfileEvent {
  const DriverProfileRequested({this.force = false});

  /// Re-reads even when the profile is already loaded — pull-to-refresh, and
  /// the return from a document upload.
  final bool force;

  @override
  List<Object?> get props => [force];
}

/// `POST /driver/documents` for one of the four types.
class DriverDocumentUploaded extends DriverProfileEvent {
  const DriverDocumentUploaded({
    required this.type,
    required this.file,
    this.backFile,
  });

  final DocumentType type;
  final UploadFile file;

  /// Only meaningful for the ID card and the driving licence; the repository
  /// drops it for the other two rather than letting the API 422.
  final UploadFile? backFile;

  @override
  List<Object?> get props => [type, file, backFile];
}

/// `PUT /driver/profile` — the default `instant_booking` for new rides.
class DriverInstantBookingDefaultChanged extends DriverProfileEvent {
  const DriverInstantBookingDefaultChanged(this.value);

  final bool value;

  @override
  List<Object?> get props => [value];
}

class DriverProfileFailureCleared extends DriverProfileEvent {
  const DriverProfileFailureCleared();
}
