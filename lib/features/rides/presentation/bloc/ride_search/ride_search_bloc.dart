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

part 'ride_search_event.dart';
part 'ride_search_state.dart';

/// `GET /rides` — the search form and its results (API.md §9).
///
/// The form and the results share one bloc because the results screen keeps
/// the form's filters in its app bar, and both have to agree on what is
/// currently being searched.
class RideSearchBloc extends Bloc<RideSearchEvent, RideSearchState> {
  RideSearchBloc({required RideRepository rides})
    : _rides = rides,
      super(const RideSearchState()) {
    on<RideSearchQueryReplaced>(_onQueryReplaced);
    on<RideSearchFieldChanged>(_onFieldChanged);
    on<RideSearchRouteSwapped>(_onRouteSwapped);
    on<RideSearchFiltersChanged>(_onFiltersChanged);
    on<RideSearchFiltersCleared>(_onFiltersCleared);

    // `restartable` so a second search cancels the first: changing the date
    // twice in a row must not let the older response land last.
    on<RideSearchSubmitted>(_onSubmitted, transformer: restartable());
    on<RideSearchRefreshed>(_onRefreshed, transformer: restartable());

    // `droppable` so a fast scroll cannot queue up four requests for the same
    // page.
    on<RideSearchMoreRequested>(_onMoreRequested, transformer: droppable());
  }

  final RideRepository _rides;

  void _onQueryReplaced(
    RideSearchQueryReplaced event,
    Emitter<RideSearchState> emit,
  ) {
    emit(state.copyWith(query: event.query, failure: () => null));
    if (event.submit) add(const RideSearchSubmitted());
  }

  void _onFieldChanged(
    RideSearchFieldChanged event,
    Emitter<RideSearchState> emit,
  ) {
    emit(
      state.copyWith(
        query: state.query.copyWith(
          fromCityId: event.fromCityId == null ? null : () => event.fromCityId,
          toCityId: event.toCityId == null ? null : () => event.toCityId,
          date: event.clearDate
              ? () => null
              : (event.date == null ? null : () => event.date),
          seats: event.seats,
        ),
        failure: () => null,
      ),
    );
  }

  void _onRouteSwapped(
    RideSearchRouteSwapped event,
    Emitter<RideSearchState> emit,
  ) {
    emit(state.copyWith(query: state.query.swapped()));
  }

  void _onFiltersChanged(
    RideSearchFiltersChanged event,
    Emitter<RideSearchState> emit,
  ) {
    final previous = state.query;
    final next = previous.copyWith(
      sort: event.sort,
      maxPrice: event.clearMaxPrice
          ? () => null
          : (event.maxPrice == null ? null : () => event.maxPrice),
      bands: event.bands,
    );
    emit(state.copyWith(query: next));

    // `sort` is a server parameter, so it needs a new request. The price
    // ceiling and the time bands are applied to the loaded pages by
    // `RideSearchState.rides`, so changing them only re-renders.
    if (next.needsRefetchFrom(previous)) add(const RideSearchSubmitted());
  }

  void _onFiltersCleared(
    RideSearchFiltersCleared event,
    Emitter<RideSearchState> emit,
  ) {
    final previous = state.query;
    final next = previous.clearedFilters();
    emit(state.copyWith(query: next));
    if (next.needsRefetchFrom(previous)) add(const RideSearchSubmitted());
  }

  Future<void> _onSubmitted(
    RideSearchSubmitted event,
    Emitter<RideSearchState> emit,
  ) => _load(emit, refreshing: false);

  Future<void> _onRefreshed(
    RideSearchRefreshed event,
    Emitter<RideSearchState> emit,
  ) => _load(emit, refreshing: true);

  Future<void> _load(
    Emitter<RideSearchState> emit, {
    required bool refreshing,
  }) async {
    if (!state.canSearch) return;

    emit(
      state.copyWith(
        status: refreshing ? DataStatus.refreshing : DataStatus.loading,
        failure: () => null,
      ),
    );

    final result = await _rides.search(state.query);
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
    RideSearchMoreRequested event,
    Emitter<RideSearchState> emit,
  ) async {
    if (!state.hasMore || state.isLoadingMore || state.status.isBusy) return;

    emit(state.copyWith(isLoadingMore: true, failure: () => null));

    final result = await _rides.search(state.query, page: state.page.nextPage);
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(isLoadingMore: false, page: state.page.concat(value)),
        );
      case Err(:final failure):
        // The rides already on screen stay; only the footer reports the
        // failure, so a flaky "load more" never costs the user their results.
        emit(state.copyWith(isLoadingMore: false, failure: () => failure));
    }
  }
}
