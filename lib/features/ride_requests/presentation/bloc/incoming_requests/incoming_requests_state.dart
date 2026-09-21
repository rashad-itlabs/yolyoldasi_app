part of 'incoming_requests_bloc.dart';

class IncomingRequestsState extends Equatable {
  const IncomingRequestsState({
    this.status = DataStatus.initial,
    this.page = const Paginated<RideRequest>.empty(),
    this.isLoadingMore = false,
    this.fromCityId,
    this.toCityId,
    this.failure,
  });

  final DataStatus status;
  final Paginated<RideRequest> page;
  final bool isLoadingMore;

  /// Held so "load more" asks for the same slice the first page came from.
  final int? fromCityId;
  final int? toCityId;

  final Failure? failure;

  List<RideRequest> get requests => page.items;

  bool get isEmpty => status.isSuccess && requests.isEmpty;

  /// Seats being asked for across every open request — the one number worth
  /// putting in front of a driver deciding whether to publish.
  int get totalSeatsWanted =>
      requests.fold(0, (sum, request) => sum + request.seats);

  IncomingRequestsState copyWith({
    DataStatus? status,
    Paginated<RideRequest>? page,
    bool? isLoadingMore,
    int? Function()? fromCityId,
    int? Function()? toCityId,
    Failure? Function()? failure,
  }) {
    return IncomingRequestsState(
      status: status ?? this.status,
      page: page ?? this.page,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      fromCityId: fromCityId != null ? fromCityId() : this.fromCityId,
      toCityId: toCityId != null ? toCityId() : this.toCityId,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [
    status,
    page,
    isLoadingMore,
    fromCityId,
    toCityId,
    failure,
  ];
}
