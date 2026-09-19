part of 'booking_request_bloc.dart';

sealed class BookingRequestEvent extends Equatable {
  const BookingRequestEvent();

  @override
  List<Object?> get props => const [];
}

/// Opens the sheet for a ride, carrying the numbers the seat stepper needs.
class BookingRequestStarted extends BookingRequestEvent {
  const BookingRequestStarted({
    required this.rideId,
    required this.seatsAvailable,
    required this.pricePerSeat,
  });

  final int rideId;

  /// `seats_left` from the ride, straight from the server (API.md §16.3).
  final int seatsAvailable;

  final double pricePerSeat;

  @override
  List<Object?> get props => [rideId, seatsAvailable, pricePerSeat];
}

class BookingRequestSeatsChanged extends BookingRequestEvent {
  const BookingRequestSeatsChanged(this.seats);

  final int seats;

  @override
  List<Object?> get props => [seats];
}

class BookingRequestMessageChanged extends BookingRequestEvent {
  const BookingRequestMessageChanged(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class BookingRequestSubmitted extends BookingRequestEvent {
  const BookingRequestSubmitted();
}

class BookingRequestFailureCleared extends BookingRequestEvent {
  const BookingRequestFailureCleared();
}
