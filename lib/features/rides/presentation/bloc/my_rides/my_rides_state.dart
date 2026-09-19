part of 'my_rides_bloc.dart';

class MyRidesState extends Equatable {
  const MyRidesState({
    this.status = DataStatus.initial,
    this.page = const Paginated<Ride>.empty(),
    this.filter,
    this.isLoadingMore = false,
    this.busyRideId,
    this.actionStatus = ActionStatus.idle,
    this.failure,
  });

  final DataStatus status;
  final Paginated<Ride> page;

  /// `null` shows every status.
  final RideStatus? filter;

  final bool isLoadingMore;

  /// Which row has an action in flight, so only that card shows a spinner.
  final int? busyRideId;
  final ActionStatus actionStatus;

  final Failure? failure;

  List<Ride> get rides => page.items;
  bool get isEmpty => status.isSuccess && rides.isEmpty;
  bool get hasMore => page.hasMore;

  bool isBusy(int rideId) => busyRideId == rideId && actionStatus.isInProgress;

  /// Upcoming active rides, which the home screen leads with.
  List<Ride> get upcoming => rides
      .where((r) => r.status.isActive && !r.hasDeparted)
      .toList(growable: false);

  MyRidesState copyWith({
    DataStatus? status,
    Paginated<Ride>? page,
    RideStatus? Function()? filter,
    bool? isLoadingMore,
    int? Function()? busyRideId,
    ActionStatus? actionStatus,
    Failure? Function()? failure,
  }) {
    return MyRidesState(
      status: status ?? this.status,
      page: page ?? this.page,
      filter: filter != null ? filter() : this.filter,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      busyRideId: busyRideId != null ? busyRideId() : this.busyRideId,
      actionStatus: actionStatus ?? this.actionStatus,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [
    status,
    page,
    filter,
    isLoadingMore,
    busyRideId,
    actionStatus,
    failure,
  ];
}
