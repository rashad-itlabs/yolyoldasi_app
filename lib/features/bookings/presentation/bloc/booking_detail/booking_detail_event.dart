part of 'booking_detail_bloc.dart';

sealed class BookingDetailEvent extends Equatable {
  const BookingDetailEvent();

  @override
  List<Object?> get props => const [];
}

class BookingDetailRequested extends BookingDetailEvent {
  const BookingDetailRequested(this.bookingId);

  final int bookingId;

  @override
  List<Object?> get props => [bookingId];
}

/// `POST /bookings/{id}/confirm` — driver only.
class BookingDetailConfirmed extends BookingDetailEvent {
  const BookingDetailConfirmed();
}

/// `POST /bookings/{id}/reject` — driver only. Locks the conversation.
class BookingDetailRejected extends BookingDetailEvent {
  const BookingDetailRejected();
}

/// `POST /bookings/{id}/cancel` — either side, while the ride has not departed.
class BookingDetailCancelled extends BookingDetailEvent {
  const BookingDetailCancelled({this.reason});

  /// Optional, ≤255 characters.
  final String? reason;

  @override
  List<Object?> get props => [reason];
}

/// `POST /bookings/{id}/block` — driver only. Shuts the ride to a passenger
/// who cancelled, so they cannot re-book it.
class BookingDetailPassengerBlocked extends BookingDetailEvent {
  const BookingDetailPassengerBlocked();
}

/// `POST /bookings/{id}/unblock` — driver only. Reopens the ride to them.
class BookingDetailPassengerUnblocked extends BookingDetailEvent {
  const BookingDetailPassengerUnblocked();
}

class BookingDetailFailureCleared extends BookingDetailEvent {
  const BookingDetailFailureCleared();
}
