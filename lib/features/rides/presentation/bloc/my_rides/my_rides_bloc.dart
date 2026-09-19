import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/data_status.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/result.dart';
import '../../../../../core/network/api_envelope.dart';
import '../../../domain/entities/ride.dart';
import '../../../domain/repositories/ride_repository.dart';

part 'my_rides_event.dart';
part 'my_rides_state.dart';

/// `GET /rides/mine` — the driver's own listings, plus the actions on them.
class MyRidesBloc extends Bloc<MyRidesEvent, MyRidesState> {
  MyRidesBloc({required RideRepository rides})
    : _rides = rides,
      super(const MyRidesState()) {
    on<MyRidesRequested>(_onRequested, transformer: restartable());
    on<MyRidesFilterChanged>(_onFilterChanged, transformer: restartable());
    on<MyRidesMoreRequested>(_onMoreRequested, transformer: droppable());
    on<MyRideStatusToggled>(_onStatusToggled);
    on<MyRideCancelled>(_onCancelled);
    on<MyRideCompleted>(_onCompleted);
    on<MyRidesFailureCleared>(_onFailureCleared);
  }

  final RideRepository _rides;

  Future<void> _onRequested(
    MyRidesRequested event,
    Emitter<MyRidesState> emit,
  ) async {
    final hasData = state.page.isNotEmpty;
    emit(
      state.copyWith(
        status: hasData && event.refresh
            ? DataStatus.refreshing
            : DataStatus.loading,
        failure: () => null,
      ),
    );
    await _load(emit);
  }

  Future<void> _onFilterChanged(
    MyRidesFilterChanged event,
    Emitter<MyRidesState> emit,
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

  Future<void> _load(Emitter<MyRidesState> emit) async {
    final result = await _rides.mine(status: state.filter);
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(status: DataStatus.success, page: value));
      case Err(:final failure):
        emit(
          state.copyWith(status: DataStatus.failure, failure: () => failure),
        );
    }
  }

  Future<void> _onMoreRequested(
    MyRidesMoreRequested event,
    Emitter<MyRidesState> emit,
  ) async {
    if (!state.page.hasMore || state.isLoadingMore || state.status.isBusy) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true));

    final result = await _rides.mine(
      status: state.filter,
      page: state.page.nextPage,
    );
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(isLoadingMore: false, page: state.page.concat(value)),
        );
      case Err(:final failure):
        emit(state.copyWith(isLoadingMore: false, failure: () => failure));
    }
  }

  Future<void> _onStatusToggled(
    MyRideStatusToggled event,
    Emitter<MyRidesState> emit,
  ) async {
    await _act(emit, event.rideId, () async {
      final result = await _rides.setStatus(event.rideId, event.status);
      return result.map(_replace);
    });
  }

  Future<void> _onCancelled(
    MyRideCancelled event,
    Emitter<MyRidesState> emit,
  ) async {
    await _act(emit, event.rideId, () async {
      final result = await _rides.cancel(event.rideId);
      // Cancelling also cancels every pending and confirmed booking
      // (API.md §9), so the row is re-read rather than patched locally.
      return result.map((_) => _withStatus(event.rideId, RideStatus.cancelled));
    });
  }

  Future<void> _onCompleted(
    MyRideCompleted event,
    Emitter<MyRidesState> emit,
  ) async {
    await _act(emit, event.rideId, () async {
      final result = await _rides.complete(event.rideId);
      return result.map((_) => _withStatus(event.rideId, RideStatus.completed));
    });
  }

  /// Runs a per-ride action, tracking which row is busy so only its own
  /// spinner shows.
  Future<void> _act(
    Emitter<MyRidesState> emit,
    int rideId,
    Future<Result<Paginated<Ride>>> Function() action,
  ) async {
    if (state.busyRideId != null) return;

    emit(
      state.copyWith(
        busyRideId: () => rideId,
        actionStatus: ActionStatus.inProgress,
        failure: () => null,
      ),
    );

    final result = await action();
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            page: value,
            busyRideId: () => null,
            actionStatus: ActionStatus.success,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            busyRideId: () => null,
            actionStatus: ActionStatus.failure,
            failure: () => failure,
          ),
        );
    }
  }

  Paginated<Ride> _replace(Ride updated) => state.page.replacingItems([
    for (final ride in state.page.items)
      if (ride.id == updated.id) updated else ride,
  ]);

  Paginated<Ride> _withStatus(int rideId, RideStatus status) =>
      state.page.replacingItems([
        for (final ride in state.page.items)
          if (ride.id == rideId) ride.copyWith(status: status) else ride,
      ]);

  void _onFailureCleared(
    MyRidesFailureCleared event,
    Emitter<MyRidesState> emit,
  ) {
    emit(state.copyWith(failure: () => null, actionStatus: ActionStatus.idle));
  }
}
