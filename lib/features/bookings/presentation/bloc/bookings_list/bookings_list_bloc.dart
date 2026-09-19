import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/data_status.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/result.dart';
import '../../../../../core/network/api_envelope.dart';
import '../../../domain/entities/booking.dart';
import '../../../domain/repositories/booking_repository.dart';

part 'bookings_list_event.dart';
part 'bookings_list_state.dart';

/// `GET /bookings` and `GET /bookings/incoming`, plus the decisions on them.
///
/// One bloc for both because the bookings screen is a two-tab view of the same
/// shape, and the driver's per-ride list is the incoming one narrowed by ride.
class BookingsListBloc extends Bloc<BookingsListEvent, BookingsListState> {
  BookingsListBloc({
    required BookingRepository bookings,
    BookingScope scope = BookingScope.mine,
    int? rideId,
  }) : _bookings = bookings,
       super(BookingsListState(scope: scope, rideId: rideId)) {
    on<BookingsListRequested>(_onRequested, transformer: restartable());
    on<BookingsListScopeChanged>(_onScopeChanged, transformer: restartable());
    on<BookingsListFilterChanged>(_onFilterChanged, transformer: restartable());
    on<BookingsListMoreRequested>(_onMoreRequested, transformer: droppable());
    on<BookingConfirmed>(_onConfirmed);
    on<BookingRejected>(_onRejected);
    on<BookingCancelled>(_onCancelled);
    on<BookingPassengerBlockChanged>(_onPassengerBlockChanged);
    on<BookingsListFailureCleared>(_onFailureCleared);
  }

  final BookingRepository _bookings;

  Future<void> _onRequested(
    BookingsListRequested event,
    Emitter<BookingsListState> emit,
  ) async {
    emit(
      state.copyWith(
        status: state.page.isNotEmpty && event.refresh
            ? DataStatus.refreshing
            : DataStatus.loading,
        failure: () => null,
      ),
    );
    await _load(emit);
  }

  Future<void> _onScopeChanged(
    BookingsListScopeChanged event,
    Emitter<BookingsListState> emit,
  ) async {
    if (state.scope == event.scope) return;
    emit(
      state.copyWith(
        scope: event.scope,
        status: DataStatus.loading,
        page: const Paginated<Booking>.empty(),
        failure: () => null,
      ),
    );
    await _load(emit);
  }

  Future<void> _onFilterChanged(
    BookingsListFilterChanged event,
    Emitter<BookingsListState> emit,
  ) async {
    if (state.filter == event.status) return;
    emit(
      state.copyWith(
        filter: () => event.status,
        status: DataStatus.loading,
        failure: () => null,
      ),
    );
    await _load(emit);
  }

  Future<void> _load(Emitter<BookingsListState> emit) async {
    final result = await _fetch();
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(status: DataStatus.success, page: value));
      case Err(:final failure):
        emit(
          state.copyWith(status: DataStatus.failure, failure: () => failure),
        );
    }
  }

  Future<Result<Paginated<Booking>>> _fetch({int? page}) =>
      state.scope.isIncoming
      ? _bookings.incoming(status: state.filter, page: page)
      : _bookings.mine(status: state.filter, page: page);

  Future<void> _onMoreRequested(
    BookingsListMoreRequested event,
    Emitter<BookingsListState> emit,
  ) async {
    if (!state.hasMore || state.isLoadingMore || state.status.isBusy) return;

    emit(state.copyWith(isLoadingMore: true));

    final result = await _fetch(page: state.page.nextPage);
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(isLoadingMore: false, page: state.page.concat(value)),
        );
      case Err(:final failure):
        emit(state.copyWith(isLoadingMore: false, failure: () => failure));
    }
  }

  Future<void> _onConfirmed(
    BookingConfirmed event,
    Emitter<BookingsListState> emit,
  ) => _decide(
    emit,
    event.bookingId,
    BookingAction.confirm,
    () => _bookings.confirm(event.bookingId),
  );

  Future<void> _onRejected(
    BookingRejected event,
    Emitter<BookingsListState> emit,
  ) => _decide(
    emit,
    event.bookingId,
    BookingAction.reject,
    () => _bookings.reject(event.bookingId),
  );

  Future<void> _onCancelled(
    BookingCancelled event,
    Emitter<BookingsListState> emit,
  ) => _decide(
    emit,
    event.bookingId,
    BookingAction.cancel,
    () => _bookings.cancel(event.bookingId, reason: event.reason),
  );

  Future<void> _onPassengerBlockChanged(
    BookingPassengerBlockChanged event,
    Emitter<BookingsListState> emit,
  ) => _decide(
    emit,
    event.bookingId,
    event.blocked ? BookingAction.block : BookingAction.unblock,
    () => event.blocked
        ? _bookings.blockPassenger(event.bookingId)
        : _bookings.unblockPassenger(event.bookingId),
  );

  /// Runs a per-booking action and splices the updated booking back into the
  /// page, so the card re-renders without re-reading the whole list.
  Future<void> _decide(
    Emitter<BookingsListState> emit,
    int bookingId,
    BookingAction which,
    Future<Result<Booking>> Function() action,
  ) async {
    if (state.actionStatus.isInProgress) return;

    emit(
      state.copyWith(
        actionBookingId: () => bookingId,
        lastAction: () => which,
        actionStatus: ActionStatus.inProgress,
        failure: () => null,
      ),
    );

    final result = await action();
    switch (result) {
      case Ok(:final value):
        // `actionBookingId` is left set on purpose: the screen reads the new
        // status off that row to say which of confirm/reject/cancel landed.
        emit(
          state.copyWith(
            page: state.page.replacingItems([
              for (final booking in state.page.items)
                if (booking.id == value.id) value else booking,
            ]),
            actionStatus: ActionStatus.success,
          ),
        );
      case Err(:final failure):
        // Typically a 422: already decided, or the seats went while the
        // request sat in the driver's list.
        emit(
          state.copyWith(
            actionStatus: ActionStatus.failure,
            failure: () => failure,
          ),
        );
    }
  }

  void _onFailureCleared(
    BookingsListFailureCleared event,
    Emitter<BookingsListState> emit,
  ) {
    emit(state.copyWith(failure: () => null, actionStatus: ActionStatus.idle));
  }
}
