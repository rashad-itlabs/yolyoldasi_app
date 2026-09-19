import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/data_status.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/result.dart';
import '../../../domain/entities/recent_search.dart';
import '../../../domain/repositories/ride_repository.dart';

part 'recent_searches_event.dart';
part 'recent_searches_state.dart';

/// `GET /me/recent-searches` — the quick-repeat chips on the search screen.
///
/// The server records a search on every `GET /rides` and keeps the last ten
/// (API.md §14), so this bloc only ever reads and clears.
class RecentSearchesBloc
    extends Bloc<RecentSearchesEvent, RecentSearchesState> {
  RecentSearchesBloc({required RideRepository rides})
    : _rides = rides,
      super(const RecentSearchesState()) {
    on<RecentSearchesRequested>(_onRequested);
    on<RecentSearchesCleared>(_onCleared);
  }

  final RideRepository _rides;

  Future<void> _onRequested(
    RecentSearchesRequested event,
    Emitter<RecentSearchesState> emit,
  ) async {
    if (state.status.isBusy) return;

    emit(
      state.copyWith(
        status: state.searches.isEmpty
            ? DataStatus.loading
            : DataStatus.refreshing,
        failure: () => null,
      ),
    );

    final result = await _rides.recentSearches();
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(status: DataStatus.success, searches: value));
      case Err(:final failure):
        // The chips are a convenience; a failure hides them rather than
        // taking over the search screen with an error.
        emit(
          state.copyWith(status: DataStatus.failure, failure: () => failure),
        );
    }
  }

  Future<void> _onCleared(
    RecentSearchesCleared event,
    Emitter<RecentSearchesState> emit,
  ) async {
    final previous = state.searches;
    emit(state.copyWith(searches: const [], status: DataStatus.success));

    final result = await _rides.clearRecentSearches();
    if (result case Err(:final failure)) {
      emit(state.copyWith(searches: previous, failure: () => failure));
    }
  }
}
