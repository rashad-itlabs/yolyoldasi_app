import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/data_status.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/result.dart';
import '../../../../../core/network/api_envelope.dart';
import '../../../domain/entities/ride_request.dart';
import '../../../domain/repositories/ride_request_repository.dart';

part 'incoming_requests_event.dart';
part 'incoming_requests_state.dart';

/// What passengers want on the routes this driver runs — `GET
/// /ride-requests/incoming`.
///
/// The screen a driver opens instead of guessing. No route is sent by default:
/// the server picks them from the driver's own past listings, and falls back to
/// their home city for a driver who has not published yet — which is exactly
/// the person most in need of a reason to.
class IncomingRequestsBloc
    extends Bloc<IncomingRequestsEvent, IncomingRequestsState> {
  IncomingRequestsBloc({required RideRequestRepository requests})
    : _requests = requests,
      super(const IncomingRequestsState()) {
    on<IncomingRequestsRequested>(_onRequested, transformer: restartable());
    on<IncomingRequestsMoreRequested>(
      _onMoreRequested,
      transformer: droppable(),
    );
  }

  final RideRequestRepository _requests;

  Future<void> _onRequested(
    IncomingRequestsRequested event,
    Emitter<IncomingRequestsState> emit,
  ) async {
    final hasData = state.page.isNotEmpty;
    emit(
      state.copyWith(
        status: hasData && event.refresh
            ? DataStatus.refreshing
            : DataStatus.loading,
        fromCityId: () => event.fromCityId,
        toCityId: () => event.toCityId,
        failure: () => null,
      ),
    );

    final result = await _requests.incoming(
      fromCityId: event.fromCityId,
      toCityId: event.toCityId,
    );

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
    IncomingRequestsMoreRequested event,
    Emitter<IncomingRequestsState> emit,
  ) async {
    if (!state.page.hasMore || state.isLoadingMore || state.status.isBusy) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true));

    final result = await _requests.incoming(
      fromCityId: state.fromCityId,
      toCityId: state.toCityId,
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
}
