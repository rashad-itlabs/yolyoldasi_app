import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/data_status.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/result.dart';
import '../../../../../core/network/api_envelope.dart';
import '../../../domain/entities/ride.dart';
import '../../../domain/entities/ride_query.dart';
import '../../../domain/repositories/ride_repository.dart';

part 'ride_browse_event.dart';
part 'ride_browse_state.dart';

/// `GET /rides` with no route — every active ride, soonest first (API.md §9).
///
/// Separate from `RideSearchBloc` on purpose: that one belongs to the search
/// form and keeps whatever the passenger typed, while this one is always the
/// same query. Sharing a bloc would mean the browse list emptied itself the
/// moment somebody picked a city in the form above it.
class RideBrowseBloc extends Bloc<RideBrowseEvent, RideBrowseState> {
  RideBrowseBloc({required RideRepository rides})
    : _rides = rides,
      super(const RideBrowseState()) {
    on<RideBrowseRequested>(_onRequested, transformer: restartable());
    on<RideBrowseMoreRequested>(_onMoreRequested, transformer: droppable());
    on<_RideBrowseChanged>(_onChanged, transformer: restartable());

    // A driver who switches to passenger mode should find the ride they just
    // published in the list, not the one loaded before they published it.
    _changes = rides.changes.listen((_) => add(const _RideBrowseChanged()));
  }

  final RideRepository _rides;
  late final StreamSubscription<void> _changes;

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }

  /// Re-reads the first page in place; a failure keeps what is listed.
  Future<void> _onChanged(
    _RideBrowseChanged event,
    Emitter<RideBrowseState> emit,
  ) async {
    if (state.status.isFirstLoad) return;

    final result = await _rides.search(_everything);
    if (result case Ok(:final value)) {
      emit(state.copyWith(status: DataStatus.success, page: value));
    }
  }

  /// No cities and no date: everything on offer. `seats: 1` is the default the
  /// API applies anyway, and it keeps full rides out of a list nobody can book
  /// from.
  static const RideSearchQuery _everything = RideSearchQuery();

  Future<void> _onRequested(
    RideBrowseRequested event,
    Emitter<RideBrowseState> emit,
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

    final result = await _rides.search(_everything);
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
    RideBrowseMoreRequested event,
    Emitter<RideBrowseState> emit,
  ) async {
    if (!state.hasMore || state.isLoadingMore || state.status.isBusy) return;

    emit(state.copyWith(isLoadingMore: true, failure: () => null));

    final result = await _rides.search(_everything, page: state.page.nextPage);
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(isLoadingMore: false, page: state.page.concat(value)),
        );
      case Err(:final failure):
        // What is already listed stays put; only the footer says anything, so
        // a flaky next page never costs the passenger the rides they can see.
        emit(state.copyWith(isLoadingMore: false, failure: () => failure));
    }
  }
}
