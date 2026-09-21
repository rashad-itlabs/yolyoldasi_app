import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/data_status.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/result.dart';
import '../../../../../core/network/api_envelope.dart';
import '../../../../rides/domain/entities/ride.dart';
import '../../../domain/entities/ride_request.dart';
import '../../../domain/repositories/ride_request_repository.dart';

part 'ride_requests_event.dart';
part 'ride_requests_state.dart';

/// The passenger's own ride requests — listing them, posting one, closing one.
///
/// Creation lives here rather than in a form-only bloc because the two are the
/// same screen's concern: the list is what the passenger sees after posting,
/// and the matches that come back with a new request belong on it immediately.
class RideRequestsBloc extends Bloc<RideRequestsEvent, RideRequestsState> {
  RideRequestsBloc({required RideRequestRepository requests})
    : _requests = requests,
      super(const RideRequestsState()) {
    on<RideRequestsRequested>(_onRequested, transformer: restartable());
    on<RideRequestsMoreRequested>(_onMoreRequested, transformer: droppable());
    on<RideRequestSubmitted>(_onSubmitted, transformer: droppable());
    on<RideRequestCancelled>(_onCancelled);
    on<RideRequestsFailureCleared>(_onFailureCleared);
  }

  final RideRequestRepository _requests;

  Future<void> _onRequested(
    RideRequestsRequested event,
    Emitter<RideRequestsState> emit,
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

    final result = await _requests.mine();
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
    RideRequestsMoreRequested event,
    Emitter<RideRequestsState> emit,
  ) async {
    if (!state.page.hasMore || state.isLoadingMore || state.status.isBusy) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true));

    final result = await _requests.mine(page: state.page.nextPage);
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(isLoadingMore: false, page: state.page.concat(value)),
        );
      case Err(:final failure):
        emit(state.copyWith(isLoadingMore: false, failure: () => failure));
    }
  }

  Future<void> _onSubmitted(
    RideRequestSubmitted event,
    Emitter<RideRequestsState> emit,
  ) async {
    emit(
      state.copyWith(
        actionStatus: ActionStatus.inProgress,
        failure: () => null,
        lastMatches: () => const [],
      ),
    );

    final result = await _requests.create(event.draft);

    switch (result) {
      case Ok(:final value):
        // The new row goes to the front and any older row for the same route
        // and date drops out: the API updates in place rather than inserting a
        // second one, so keeping both would show the passenger a duplicate
        // that does not exist on the server.
        final others = state.requests
            .where((r) => r.id != value.request.id)
            .toList();

        emit(
          state.copyWith(
            actionStatus: ActionStatus.success,
            page: state.page.replacingItems([value.request, ...others]),
            lastCreated: () => value.request,
            lastMatches: () => value.matches,
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

  Future<void> _onCancelled(
    RideRequestCancelled event,
    Emitter<RideRequestsState> emit,
  ) async {
    if (state.busyRequestId != null) return;

    emit(
      state.copyWith(
        busyRequestId: () => event.requestId,
        failure: () => null,
      ),
    );

    final result = await _requests.cancel(event.requestId);

    switch (result) {
      case Ok(:final value):
        // Dropped from the list rather than left showing "cancelled": the
        // screen's whole subject is what the passenger is still waiting for.
        emit(
          state.copyWith(
            busyRequestId: () => null,
            page: state.page.replacingItems([
              for (final request in state.requests)
                if (request.id != value.id) request,
            ]),
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(busyRequestId: () => null, failure: () => failure),
        );
    }
  }

  void _onFailureCleared(
    RideRequestsFailureCleared event,
    Emitter<RideRequestsState> emit,
  ) {
    emit(state.copyWith(failure: () => null, actionStatus: ActionStatus.idle));
  }
}
