import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/data_status.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/result.dart';
import '../../../../../core/localization/app_strings.dart';
import '../../../domain/entities/booking.dart';
import '../../../domain/repositories/booking_repository.dart';

part 'booking_request_event.dart';
part 'booking_request_state.dart';

/// `POST /rides/{id}/bookings` — the request sheet on the ride detail screen.
class BookingRequestBloc
    extends Bloc<BookingRequestEvent, BookingRequestState> {
  BookingRequestBloc({required BookingRepository bookings})
    : _bookings = bookings,
      super(const BookingRequestState()) {
    on<BookingRequestStarted>(_onStarted);
    on<BookingRequestSeatsChanged>(_onSeatsChanged);
    on<BookingRequestMessageChanged>(_onMessageChanged);
    on<BookingRequestSubmitted>(_onSubmitted);
    on<BookingRequestFailureCleared>(_onFailureCleared);
  }

  final BookingRepository _bookings;

  void _onStarted(
    BookingRequestStarted event,
    Emitter<BookingRequestState> emit,
  ) {
    emit(
      BookingRequestState(
        rideId: event.rideId,
        seatsAvailable: event.seatsAvailable,
        pricePerSeat: event.pricePerSeat,
        request: const BookingRequest(seats: 1),
      ),
    );
  }

  void _onSeatsChanged(
    BookingRequestSeatsChanged event,
    Emitter<BookingRequestState> emit,
  ) {
    final seats = event.seats.clamp(
      AppRules.minSeatsPerRide,
      state.maxSelectableSeats,
    );
    emit(
      state.copyWith(
        request: state.request.copyWith(seats: seats),
        failure: () => null,
      ),
    );
  }

  void _onMessageChanged(
    BookingRequestMessageChanged event,
    Emitter<BookingRequestState> emit,
  ) {
    emit(
      state.copyWith(
        request: state.request.copyWith(message: event.message),
        failure: () => null,
      ),
    );
  }

  Future<void> _onSubmitted(
    BookingRequestSubmitted event,
    Emitter<BookingRequestState> emit,
  ) async {
    final rideId = state.rideId;
    if (rideId == null || !state.canSubmit) return;

    emit(
      state.copyWith(
        status: ActionStatus.inProgress,
        createdBooking: () => null,
        failure: () => null,
      ),
    );

    final result = await _bookings.request(rideId, state.request);
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            status: ActionStatus.success,
            createdBooking: () => value,
          ),
        );
      case Err(:final failure):
        // A 409 is the one failure the sheet has to explain in its own words:
        // API.md §10 makes it permanent, so "try again" is wrong advice.
        emit(
          state.copyWith(status: ActionStatus.failure, failure: () => failure),
        );
    }
  }

  void _onFailureCleared(
    BookingRequestFailureCleared event,
    Emitter<BookingRequestState> emit,
  ) {
    emit(state.copyWith(failure: () => null, status: ActionStatus.idle));
  }
}
