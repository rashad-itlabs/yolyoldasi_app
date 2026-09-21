part of 'ride_requests_bloc.dart';

class RideRequestsState extends Equatable {
  const RideRequestsState({
    this.status = DataStatus.initial,
    this.page = const Paginated<RideRequest>.empty(),
    this.isLoadingMore = false,
    this.actionStatus = ActionStatus.idle,
    this.busyRequestId,
    this.lastCreated,
    this.lastMatches = const [],
    this.failure,
  });

  final DataStatus status;
  final Paginated<RideRequest> page;
  final bool isLoadingMore;

  final ActionStatus actionStatus;

  /// Which row is being closed, so only its own spinner runs.
  final int? busyRequestId;

  /// The request just posted. The sheet listens for it to close itself and to
  /// know what to say.
  final RideRequest? lastCreated;

  /// Rides that already matched the request just posted.
  ///
  /// This is what keeps the feature from feeling like a suggestion box: a
  /// passenger who describes a route should not land on "we will let you know"
  /// when a ride is sitting there right now.
  final List<Ride> lastMatches;

  final Failure? failure;

  List<RideRequest> get requests => page.items;

  bool get isEmpty => status.isSuccess && requests.isEmpty;

  /// Rows still waiting for a driver — what the screen is really about.
  List<RideRequest> get open => requests
      .where((r) => r.status.isLive && !r.hasExpired)
      .toList(growable: false);

  bool isBusy(int requestId) => busyRequestId == requestId;

  bool get hasMatches => lastMatches.isNotEmpty;

  RideRequestsState copyWith({
    DataStatus? status,
    Paginated<RideRequest>? page,
    bool? isLoadingMore,
    ActionStatus? actionStatus,
    int? Function()? busyRequestId,
    RideRequest? Function()? lastCreated,
    List<Ride>? Function()? lastMatches,
    Failure? Function()? failure,
  }) {
    return RideRequestsState(
      status: status ?? this.status,
      page: page ?? this.page,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      actionStatus: actionStatus ?? this.actionStatus,
      busyRequestId: busyRequestId != null
          ? busyRequestId()
          : this.busyRequestId,
      lastCreated: lastCreated != null ? lastCreated() : this.lastCreated,
      lastMatches: lastMatches != null
          ? (lastMatches() ?? const [])
          : this.lastMatches,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [
    status,
    page,
    isLoadingMore,
    actionStatus,
    busyRequestId,
    lastCreated,
    lastMatches,
    failure,
  ];
}
