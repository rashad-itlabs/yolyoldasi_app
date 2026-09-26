import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/data_status.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/result.dart';
import '../../../domain/entities/ride.dart';
import '../../../domain/repositories/ride_repository.dart';

part 'ride_detail_event.dart';
part 'ride_detail_state.dart';

/// One ride — `GET /rides/{id}` — plus the driver's actions on it.
///
/// Scoped to the detail screen. `is_mine` on the ride decides which actions
/// are offered, so the bloc never needs to know who is signed in.
class RideDetailBloc extends Bloc<RideDetailEvent, RideDetailState> {
  RideDetailBloc({required RideRepository rides})
    : _rides = rides,
      super(const RideDetailState()) {
    on<RideDetailRequested>(_onRequested);
    on<RideDetailStatusToggled>(_onStatusToggled);
    on<RideDetailCancelled>(_onCancelled);
    on<RideDetailCompleted>(_onCompleted);
    on<RideDetailFailureCleared>(_onFailureCleared);

    // Editing happens on a screen pushed over this one; coming back to the
    // old price and time would look like the edit had not saved.
    _changes = rides.changes.listen((_) {
      final rideId = state.rideId;
      if (rideId != null && state.ride != null) {
        add(RideDetailRequested(rideId));
      }
    });
  }

  final RideRepository _rides;
  late final StreamSubscription<void> _changes;

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }

  Future<void> _onRequested(
    RideDetailRequested event,
    Emitter<RideDetailState> emit,
  ) async {
    emit(
      state.copyWith(
        rideId: event.rideId,
        status: state.ride == null ? DataStatus.loading : DataStatus.refreshing,
        failure: () => null,
      ),
    );

    final result = await _rides.byId(event.rideId);
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(status: DataStatus.success, ride: () => value));
      case Err(:final failure):
        emit(
          state.copyWith(
            status: state.ride == null
                ? DataStatus.failure
                : DataStatus.success,
            failure: () => failure,
          ),
        );
    }
  }

  Future<void> _onStatusToggled(
    RideDetailStatusToggled event,
    Emitter<RideDetailState> emit,
  ) async {
    final ride = state.ride;
    if (ride == null || state.actionStatus.isInProgress) return;

    emit(
      state.copyWith(
        actionStatus: ActionStatus.inProgress,
        failure: () => null,
      ),
    );

    final result = await _rides.setStatus(ride.id, event.status);
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(actionStatus: ActionStatus.success, ride: () => value),
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

  Future<void> _onCancelled(
    RideDetailCancelled event,
    Emitter<RideDetailState> emit,
  ) async {
    await _close(
      emit,
      action: _rides.cancel,
      resultingStatus: RideStatus.cancelled,
      outcome: RideDetailOutcome.cancelled,
    );
  }

  Future<void> _onCompleted(
    RideDetailCompleted event,
    Emitter<RideDetailState> emit,
  ) async {
    await _close(
      emit,
      action: _rides.complete,
      resultingStatus: RideStatus.completed,
      outcome: RideDetailOutcome.completed,
    );
  }

  /// Cancelling and completing both close the ride and have side effects the
  /// client cannot reproduce — bookings cancelled or completed, notifications
  /// raised, review requests sent — so the new status is applied locally and
  /// [RideDetailState.outcome] tells the page to report what happened.
  Future<void> _close(
    Emitter<RideDetailState> emit, {
    required Future<Result<void>> Function(int rideId) action,
    required RideStatus resultingStatus,
    required RideDetailOutcome outcome,
  }) async {
    final ride = state.ride;
    if (ride == null || state.actionStatus.isInProgress) return;

    emit(
      state.copyWith(
        actionStatus: ActionStatus.inProgress,
        outcome: () => null,
        failure: () => null,
      ),
    );

    final result = await action(ride.id);
    switch (result) {
      case Ok():
        emit(
          state.copyWith(
            actionStatus: ActionStatus.success,
            ride: () => ride.copyWith(status: resultingStatus),
            outcome: () => outcome,
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
    RideDetailFailureCleared event,
    Emitter<RideDetailState> emit,
  ) {
    emit(
      state.copyWith(
        failure: () => null,
        actionStatus: ActionStatus.idle,
        outcome: () => null,
      ),
    );
  }
}
