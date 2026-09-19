part of 'ride_detail_bloc.dart';

sealed class RideDetailEvent extends Equatable {
  const RideDetailEvent();

  @override
  List<Object?> get props => const [];
}

class RideDetailRequested extends RideDetailEvent {
  const RideDetailRequested(this.rideId);

  final int rideId;

  @override
  List<Object?> get props => [rideId];
}

/// `PUT /rides/{id}` with `active` or `inactive`.
class RideDetailStatusToggled extends RideDetailEvent {
  const RideDetailStatusToggled(this.status);

  final RideStatus status;

  @override
  List<Object?> get props => [status];
}

/// `DELETE /rides/{id}`. Confirmed with the driver before it is fired: every
/// pending and confirmed booking goes with it.
class RideDetailCancelled extends RideDetailEvent {
  const RideDetailCancelled();
}

/// `POST /rides/{id}/complete`.
class RideDetailCompleted extends RideDetailEvent {
  const RideDetailCompleted();
}

class RideDetailFailureCleared extends RideDetailEvent {
  const RideDetailFailureCleared();
}
