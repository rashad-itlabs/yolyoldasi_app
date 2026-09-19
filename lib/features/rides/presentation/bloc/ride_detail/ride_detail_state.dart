part of 'ride_detail_bloc.dart';

/// A closing action that succeeded, for the page to announce once.
enum RideDetailOutcome { cancelled, completed }

class RideDetailState extends Equatable {
  const RideDetailState({
    this.status = DataStatus.initial,
    this.rideId,
    this.ride,
    this.actionStatus = ActionStatus.idle,
    this.outcome,
    this.failure,
  });

  final DataStatus status;
  final int? rideId;
  final Ride? ride;

  final ActionStatus actionStatus;

  /// Set once, when a cancel or complete goes through.
  final RideDetailOutcome? outcome;

  final Failure? failure;

  bool get isMine => ride?.isMine ?? false;
  bool get isBookable => ride?.isBookable ?? false;

  /// Only an active ride can be hidden from search, and only the driver sees
  /// the control at all.
  bool get canToggleVisibility =>
      isMine &&
      (ride?.status == RideStatus.active ||
          ride?.status == RideStatus.inactive);

  bool get canCancel => isMine && !(ride?.status.isFinished ?? true);
  bool get canComplete => ride?.canBeCompleted ?? false;
  bool get canEdit => isMine && (ride?.status.isEditable ?? false);

  RideDetailState copyWith({
    DataStatus? status,
    int? rideId,
    Ride? Function()? ride,
    ActionStatus? actionStatus,
    RideDetailOutcome? Function()? outcome,
    Failure? Function()? failure,
  }) {
    return RideDetailState(
      status: status ?? this.status,
      rideId: rideId ?? this.rideId,
      ride: ride != null ? ride() : this.ride,
      actionStatus: actionStatus ?? this.actionStatus,
      outcome: outcome != null ? outcome() : this.outcome,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [
    status,
    rideId,
    ride,
    actionStatus,
    outcome,
    failure,
  ];
}
