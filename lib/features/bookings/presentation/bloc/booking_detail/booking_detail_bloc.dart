import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/data_status.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/result.dart';
import '../../../domain/entities/booking.dart';
import '../../../domain/repositories/booking_repository.dart';

part 'booking_detail_event.dart';
part 'booking_detail_state.dart';

/// One booking — `GET /bookings/{id}` — and the decisions available on it.
class BookingDetailBloc extends Bloc<BookingDetailEvent, BookingDetailState> {
  BookingDetailBloc({required BookingRepository bookings})
    : _bookings = bookings,
      super(const BookingDetailState()) {
    on<BookingDetailRequested>(_onRequested);
    on<BookingDetailConfirmed>(_onConfirmed);
    on<BookingDetailRejected>(_onRejected);
    on<BookingDetailCancelled>(_onCancelled);
    on<BookingDetailPassengerBlocked>(_onPassengerBlocked);
    on<BookingDetailPassengerUnblocked>(_onPassengerUnblocked);
    on<BookingDetailFailureCleared>(_onFailureCleared);
  }

  final BookingRepository _bookings;

  Future<void> _onRequested(
    BookingDetailRequested event,
    Emitter<BookingDetailState> emit,
  ) async {
    emit(
      state.copyWith(
        bookingId: event.bookingId,
        status: state.booking == null
            ? DataStatus.loading
            : DataStatus.refreshing,
        failure: () => null,
      ),
    );

    final result = await _bookings.byId(event.bookingId);
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(status: DataStatus.success, booking: () => value));
      case Err(:final failure):
        emit(
          state.copyWith(
            status: state.booking == null
                ? DataStatus.failure
                : DataStatus.success,
            failure: () => failure,
          ),
        );
    }
  }

  Future<void> _onConfirmed(
    BookingDetailConfirmed event,
    Emitter<BookingDetailState> emit,
  ) => _act(emit, BookingAction.confirm, _bookings.confirm);

  Future<void> _onRejected(
    BookingDetailRejected event,
    Emitter<BookingDetailState> emit,
  ) => _act(emit, BookingAction.reject, _bookings.reject);

  Future<void> _onCancelled(
    BookingDetailCancelled event,
    Emitter<BookingDetailState> emit,
  ) => _act(
    emit,
    BookingAction.cancel,
    (id) => _bookings.cancel(id, reason: event.reason),
  );

  Future<void> _onPassengerBlocked(
    BookingDetailPassengerBlocked event,
    Emitter<BookingDetailState> emit,
  ) => _act(emit, BookingAction.block, _bookings.blockPassenger);

  Future<void> _onPassengerUnblocked(
    BookingDetailPassengerUnblocked event,
    Emitter<BookingDetailState> emit,
  ) => _act(emit, BookingAction.unblock, _bookings.unblockPassenger);

  Future<void> _act(
    Emitter<BookingDetailState> emit,
    BookingAction which,
    Future<Result<Booking>> Function(int bookingId) action,
  ) async {
    final booking = state.booking;
    if (booking == null || state.actionStatus.isInProgress) return;

    emit(
      state.copyWith(
        actionStatus: ActionStatus.inProgress,
        lastAction: () => which,
        failure: () => null,
      ),
    );

    final result = await action(booking.id);
    switch (result) {
      case Ok(:final value):
        // The response carries the new status, and with it `contact_phone`
        // appearing or disappearing — so the whole booking is replaced rather
        // than patched.
        emit(
          state.copyWith(
            actionStatus: ActionStatus.success,
            booking: () => value,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            actionStatus: ActionStatus.failure,
            failure: () => failure,
          ),
        );
    }
  }

  void _onFailureCleared(
    BookingDetailFailureCleared event,
    Emitter<BookingDetailState> emit,
  ) {
    emit(state.copyWith(failure: () => null, actionStatus: ActionStatus.idle));
  }
}
