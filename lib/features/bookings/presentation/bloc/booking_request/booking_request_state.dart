part of 'booking_request_bloc.dart';

class BookingRequestState extends Equatable {
  const BookingRequestState({
    this.rideId,
    this.request = const BookingRequest(seats: 1),
    this.seatsAvailable = 0,
    this.pricePerSeat = 0,
    this.status = ActionStatus.idle,
    this.createdBooking,
    this.failure,
  });

  final int? rideId;
  final BookingRequest request;
  final int seatsAvailable;
  final double pricePerSeat;

  final ActionStatus status;

  /// The booking the API created, carrying the `conversation_id` the sheet
  /// offers to open.
  final Booking? createdBooking;

  final Failure? failure;

  int get seats => request.seats;

  /// Never offer more seats than the ride has left, nor more than the four a
  /// private car may carry.
  int get maxSelectableSeats =>
      seatsAvailable.clamp(AppRules.minSeatsPerRide, AppRules.maxSeatsPerRide);

  double get totalPrice => pricePerSeat * seats;

  bool get canSubmit =>
      request.isValid && seats <= maxSelectableSeats && !status.isBusy;

  /// API.md §16.4: a 409 means this ride will not take the request, and no
  /// retry will change that — so the sheet explains it instead of offering one.
  bool get isDuplicateRequest => failure is ConflictFailure;

  /// Why the 409 came back.
  ///
  /// Since a passenger's own cancellation reopens a ride, there is more than
  /// one way to land here — an active booking, a driver who decided, the
  /// cool-off after cancelling — and only the server knows which. Its prose
  /// wins; the local string is the fallback for when it sends none.
  String duplicateMessage(AppStrings l10n) {
    final fromServer = failure?.serverMessage?.trim();
    if (fromServer != null && fromServer.isNotEmpty) return fromServer;
    return l10n.alreadyRequestedBody;
  }

  BookingRequestState copyWith({
    int? rideId,
    BookingRequest? request,
    int? seatsAvailable,
    double? pricePerSeat,
    ActionStatus? status,
    Booking? Function()? createdBooking,
    Failure? Function()? failure,
  }) {
    return BookingRequestState(
      rideId: rideId ?? this.rideId,
      request: request ?? this.request,
      seatsAvailable: seatsAvailable ?? this.seatsAvailable,
      pricePerSeat: pricePerSeat ?? this.pricePerSeat,
      status: status ?? this.status,
      createdBooking: createdBooking != null
          ? createdBooking()
          : this.createdBooking,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [
    rideId,
    request,
    seatsAvailable,
    pricePerSeat,
    status,
    createdBooking,
    failure,
  ];
}
