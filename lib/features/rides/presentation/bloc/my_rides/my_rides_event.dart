part of 'my_rides_bloc.dart';

sealed class MyRidesEvent extends Equatable {
  const MyRidesEvent();

  @override
  List<Object?> get props => const [];
}

class MyRidesRequested extends MyRidesEvent {
  const MyRidesRequested({this.refresh = false});

  /// Keeps the current list on screen while re-reading, for pull-to-refresh.
  final bool refresh;

  @override
  List<Object?> get props => [refresh];
}

/// Narrows to one `status`, or clears the filter with `null`.
class MyRidesFilterChanged extends MyRidesEvent {
  const MyRidesFilterChanged(this.status);

  final RideStatus? status;

  @override
  List<Object?> get props => [status];
}

class MyRidesMoreRequested extends MyRidesEvent {
  const MyRidesMoreRequested();
}

/// Shows or hides a ride in search — `PUT /rides/{id}` with `status`.
class MyRideStatusToggled extends MyRidesEvent {
  const MyRideStatusToggled({required this.rideId, required this.status});

  final int rideId;

  /// Only `active` and `inactive` are accepted here (API.md §9).
  final RideStatus status;

  @override
  List<Object?> get props => [rideId, status];
}

/// `DELETE /rides/{id}` — cancels the ride and all of its bookings.
class MyRideCancelled extends MyRidesEvent {
  const MyRideCancelled(this.rideId);

  final int rideId;

  @override
  List<Object?> get props => [rideId];
}

/// `POST /rides/{id}/complete` — 422 while departure is still ahead.
class MyRideCompleted extends MyRidesEvent {
  const MyRideCompleted(this.rideId);

  final int rideId;

  @override
  List<Object?> get props => [rideId];
}

class MyRidesFailureCleared extends MyRidesEvent {
  const MyRidesFailureCleared();
}

/// Internal: [RideRepository.changes] fired.
class _MyRidesChanged extends MyRidesEvent {
  const _MyRidesChanged();
}
