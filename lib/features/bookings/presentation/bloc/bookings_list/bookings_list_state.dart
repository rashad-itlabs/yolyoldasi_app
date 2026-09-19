part of 'bookings_list_bloc.dart';

class BookingsListState extends Equatable {
  const BookingsListState({
    this.scope = BookingScope.mine,
    this.status = DataStatus.initial,
    this.page = const Paginated<Booking>.empty(),
    this.filter,
    this.rideId,
    this.isLoadingMore = false,
    this.actionBookingId,
    this.lastAction,
    this.actionStatus = ActionStatus.idle,
    this.failure,
  });

  final BookingScope scope;
  final DataStatus status;
  final Paginated<Booking> page;

  /// `null` shows every status.
  final BookingStatus? filter;

  /// Set when the list is scoped to one ride.
  ///
  /// The API has no `GET /rides/{id}/bookings`, so the driver's per-ride view
  /// reads `/bookings/incoming` and narrows it here. That means "load more"
  /// pages through every incoming booking, not just this ride's — correct, but
  /// worth a dedicated endpoint if the volume ever justifies one.
  final int? rideId;

  final bool isLoadingMore;

  /// Which row the last action ran on. It outlives the request so that the
  /// screen can name what happened — the outcome is read off that booking's
  /// new status, exactly as the detail screen does.
  final int? actionBookingId;

  /// What [actionStatus] refers to. Block and unblock leave `status` alone, so
  /// the booking cannot say on its own what just succeeded.
  final BookingAction? lastAction;

  final ActionStatus actionStatus;

  final Failure? failure;

  List<Booking> get bookings {
    final items = page.items;
    if (rideId == null) return items;
    return items.where((b) => b.ride.id == rideId).toList(growable: false);
  }

  bool get isEmpty => status.isSuccess && bookings.isEmpty;
  bool get hasMore => page.hasMore;

  bool isBusy(int bookingId) =>
      actionBookingId == bookingId && actionStatus.isInProgress;

  /// The booking the last action ran on, with whatever status came back.
  Booking? get actedBooking {
    final id = actionBookingId;
    if (id == null) return null;
    for (final booking in page.items) {
      if (booking.id == id) return booking;
    }
    return null;
  }

  /// Requests still waiting on the driver — the badge on the bookings tab.
  int get pendingCount =>
      bookings.where((b) => b.status == BookingStatus.pending).length;

  BookingsListState copyWith({
    BookingScope? scope,
    DataStatus? status,
    Paginated<Booking>? page,
    BookingStatus? Function()? filter,
    int? Function()? rideId,
    bool? isLoadingMore,
    int? Function()? actionBookingId,
    BookingAction? Function()? lastAction,
    ActionStatus? actionStatus,
    Failure? Function()? failure,
  }) {
    return BookingsListState(
      scope: scope ?? this.scope,
      status: status ?? this.status,
      page: page ?? this.page,
      filter: filter != null ? filter() : this.filter,
      rideId: rideId != null ? rideId() : this.rideId,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      actionBookingId: actionBookingId != null
          ? actionBookingId()
          : this.actionBookingId,
      lastAction: lastAction != null ? lastAction() : this.lastAction,
      actionStatus: actionStatus ?? this.actionStatus,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [
    scope,
    status,
    page,
    filter,
    rideId,
    isLoadingMore,
    actionBookingId,
    lastAction,
    actionStatus,
    failure,
  ];
}
