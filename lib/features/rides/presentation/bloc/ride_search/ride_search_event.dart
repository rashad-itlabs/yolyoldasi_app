part of 'ride_search_bloc.dart';

sealed class RideSearchEvent extends Equatable {
  const RideSearchEvent();

  @override
  List<Object?> get props => const [];
}

/// Replaces the whole query — used when a recent-search chip is tapped.
class RideSearchQueryReplaced extends RideSearchEvent {
  const RideSearchQueryReplaced(this.query, {this.submit = false});

  final RideSearchQuery query;

  /// Whether to run the search straight away, rather than only updating the
  /// form.
  final bool submit;

  @override
  List<Object?> get props => [query, submit];
}

/// One field of the search form changed.
class RideSearchFieldChanged extends RideSearchEvent {
  const RideSearchFieldChanged({
    this.fromCityId,
    this.toCityId,
    this.date,
    this.clearDate = false,
    this.seats,
  });

  final int? fromCityId;
  final int? toCityId;
  final DateTime? date;

  /// `date` is nullable in the query, so clearing it needs its own flag.
  final bool clearDate;

  final int? seats;

  @override
  List<Object?> get props => [fromCityId, toCityId, date, clearDate, seats];
}

/// Swaps origin and destination.
class RideSearchRouteSwapped extends RideSearchEvent {
  const RideSearchRouteSwapped();
}

/// Applies the filter sheet. `sort` re-queries; the price ceiling and the
/// departure windows only re-filter what is loaded, since `GET /rides` has no
/// parameter for them.
class RideSearchFiltersChanged extends RideSearchEvent {
  const RideSearchFiltersChanged({
    this.sort,
    this.maxPrice,
    this.clearMaxPrice = false,
    this.bands,
    this.driverGender,
    this.clearDriverGender = false,
    this.womenOnly,
    this.instantOnly,
    this.verifiedOnly,
  });

  final RideSortOption? sort;
  final double? maxPrice;
  final bool clearMaxPrice;
  final Set<TimeOfDayBand>? bands;

  /// Unlike the price ceiling and the time bands, these four are `GET /rides`
  /// parameters — changing any of them re-runs the search rather than filtering
  /// what is already on screen.
  final Gender? driverGender;
  final bool clearDriverGender;
  final bool? womenOnly;
  final bool? instantOnly;
  final bool? verifiedOnly;

  @override
  List<Object?> get props => [
    sort,
    maxPrice,
    clearMaxPrice,
    bands,
    driverGender,
    clearDriverGender,
    womenOnly,
    instantOnly,
    verifiedOnly,
  ];
}

class RideSearchFiltersCleared extends RideSearchEvent {
  const RideSearchFiltersCleared();
}

/// Runs `GET /rides` for the current query.
class RideSearchSubmitted extends RideSearchEvent {
  const RideSearchSubmitted();
}

class RideSearchRefreshed extends RideSearchEvent {
  const RideSearchRefreshed();
}

/// Loads the next page; ignored once `meta.last_page` is reached.
class RideSearchMoreRequested extends RideSearchEvent {
  const RideSearchMoreRequested();
}
