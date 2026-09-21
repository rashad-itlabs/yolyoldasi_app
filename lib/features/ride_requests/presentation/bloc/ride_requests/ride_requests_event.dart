part of 'ride_requests_bloc.dart';

sealed class RideRequestsEvent extends Equatable {
  const RideRequestsEvent();

  @override
  List<Object?> get props => const [];
}

class RideRequestsRequested extends RideRequestsEvent {
  const RideRequestsRequested({this.refresh = false});

  /// Keeps the list on screen while it reloads, instead of blanking it.
  final bool refresh;

  @override
  List<Object?> get props => [refresh];
}

class RideRequestsMoreRequested extends RideRequestsEvent {
  const RideRequestsMoreRequested();
}

/// Posts what the passenger described. Also fired from the empty search
/// result, which is the moment the whole feature exists for.
class RideRequestSubmitted extends RideRequestsEvent {
  const RideRequestSubmitted(this.draft);

  final RideRequestDraft draft;

  @override
  List<Object?> get props => [draft];
}

class RideRequestCancelled extends RideRequestsEvent {
  const RideRequestCancelled(this.requestId);

  final int requestId;

  @override
  List<Object?> get props => [requestId];
}

class RideRequestsFailureCleared extends RideRequestsEvent {
  const RideRequestsFailureCleared();
}
