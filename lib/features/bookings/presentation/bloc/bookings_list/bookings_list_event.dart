part of 'bookings_list_bloc.dart';

/// Which of the two collections in API.md §10 is being listed.
enum BookingScope {
  /// `GET /bookings` — bookings the user made as a passenger.
  mine,

  /// `GET /bookings/incoming` — requests on the user's own rides.
  incoming;

  bool get isIncoming => this == BookingScope.incoming;
}

sealed class BookingsListEvent extends Equatable {
  const BookingsListEvent();

  @override
  List<Object?> get props => const [];
}

class BookingsListRequested extends BookingsListEvent {
  const BookingsListRequested({this.refresh = false});

  final bool refresh;

  @override
  List<Object?> get props => [refresh];
}

class BookingsListScopeChanged extends BookingsListEvent {
  const BookingsListScopeChanged(this.scope);

  final BookingScope scope;

  @override
  List<Object?> get props => [scope];
}

/// Narrows to one `status`, or clears the filter with `null`.
class BookingsListFilterChanged extends BookingsListEvent {
  const BookingsListFilterChanged(this.status);

  final BookingStatus? status;

  @override
  List<Object?> get props => [status];
}

class BookingsListMoreRequested extends BookingsListEvent {
  const BookingsListMoreRequested();
}

/// `POST /bookings/{id}/confirm` — driver only.
class BookingConfirmed extends BookingsListEvent {
  const BookingConfirmed(this.bookingId);

  final int bookingId;

  @override
  List<Object?> get props => [bookingId];
}

/// `POST /bookings/{id}/reject` — driver only; also locks the conversation.
class BookingRejected extends BookingsListEvent {
  const BookingRejected(this.bookingId);

  final int bookingId;

  @override
  List<Object?> get props => [bookingId];
}

/// `POST /bookings/{id}/cancel` — either side.
class BookingCancelled extends BookingsListEvent {
  const BookingCancelled(this.bookingId, {this.reason});

  final int bookingId;
  final String? reason;

  @override
  List<Object?> get props => [bookingId, reason];
}

/// `POST /bookings/{id}/block` — driver only. Shuts the ride to a passenger
/// who cancelled. [blocked] false calls `/unblock` instead.
class BookingPassengerBlockChanged extends BookingsListEvent {
  const BookingPassengerBlockChanged(this.bookingId, {required this.blocked});

  final int bookingId;
  final bool blocked;

  @override
  List<Object?> get props => [bookingId, blocked];
}

class BookingsListFailureCleared extends BookingsListEvent {
  const BookingsListFailureCleared();
}
