part of 'driver_profile_bloc.dart';

class DriverProfileState extends Equatable {
  const DriverProfileState({
    this.status = DataStatus.initial,
    this.profile,
    this.uploadingType,
    this.uploadStatus = ActionStatus.idle,
    this.failure,
  });

  final DataStatus status;

  /// `null` until the first successful read. A user who has never started
  /// driver onboarding still gets a profile back, with all four documents at
  /// `not_uploaded`.
  final DriverProfile? profile;

  /// Which document is being uploaded, so only that row shows a spinner.
  final DocumentType? uploadingType;
  final ActionStatus uploadStatus;

  final Failure? failure;

  DriverProfile get profileOrInitial => profile ?? DriverProfile.initial;

  bool get canPublishRides => profile?.canPublishRides ?? false;

  bool isUploading(DocumentType type) =>
      uploadStatus.isInProgress && uploadingType == type;

  DriverProfileState copyWith({
    DataStatus? status,
    DriverProfile? Function()? profile,
    DocumentType? Function()? uploadingType,
    ActionStatus? uploadStatus,
    Failure? Function()? failure,
  }) {
    return DriverProfileState(
      status: status ?? this.status,
      profile: profile != null ? profile() : this.profile,
      uploadingType: uploadingType != null
          ? uploadingType()
          : this.uploadingType,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [
    status,
    profile,
    uploadingType,
    uploadStatus,
    failure,
  ];
}
