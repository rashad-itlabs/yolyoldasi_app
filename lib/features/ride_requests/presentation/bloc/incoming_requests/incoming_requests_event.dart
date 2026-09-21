part of 'incoming_requests_bloc.dart';

sealed class IncomingRequestsEvent extends Equatable {
  const IncomingRequestsEvent();

  @override
  List<Object?> get props => const [];
}

class IncomingRequestsRequested extends IncomingRequestsEvent {
  const IncomingRequestsRequested({
    this.fromCityId,
    this.toCityId,
    this.refresh = false,
  });

  /// Both null is the normal case: the server then answers for the routes this
  /// driver actually runs. A pair is only sent when the driver is looking at
  /// one specific route, such as from the publish form.
  final int? fromCityId;
  final int? toCityId;

  final bool refresh;

  @override
  List<Object?> get props => [fromCityId, toCityId, refresh];
}

class IncomingRequestsMoreRequested extends IncomingRequestsEvent {
  const IncomingRequestsMoreRequested();
}
