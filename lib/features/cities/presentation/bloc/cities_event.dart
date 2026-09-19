part of 'cities_bloc.dart';

sealed class CitiesEvent extends Equatable {
  const CitiesEvent();

  @override
  List<Object?> get props => const [];
}

/// Loads the city list if it is not already cached. Safe to fire from every
/// screen that needs cities — the repository de-duplicates.
class CitiesRequested extends CitiesEvent {
  const CitiesRequested();
}

/// Drops the cache and re-reads. Wired to the picker's retry button.
class CitiesRefreshed extends CitiesEvent {
  const CitiesRefreshed();
}

/// Narrows the visible list as the user types in a picker.
class CitiesQueryChanged extends CitiesEvent {
  const CitiesQueryChanged(this.query, {required this.languageCode});

  final String query;
  final String languageCode;

  @override
  List<Object?> get props => [query, languageCode];
}
