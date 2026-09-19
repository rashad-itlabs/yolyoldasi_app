part of 'cities_bloc.dart';

class CitiesState extends Equatable {
  const CitiesState({
    this.status = DataStatus.initial,
    this.cities = const [],
    this.visible = const [],
    this.query = '',
    this.failure,
  });

  final DataStatus status;

  /// Everything `GET /cities` returned, in the API's order.
  final List<City> cities;

  /// [cities] narrowed by [query] and sorted for the picker.
  final List<City> visible;

  final String query;
  final Failure? failure;

  bool get isEmpty => status.isSuccess && visible.isEmpty;

  /// Whether the empty state is "no city matches what you typed" rather than
  /// "the list is empty", which read very differently to a user.
  bool get isFilteredEmpty => isEmpty && query.trim().isNotEmpty;

  CitiesState copyWith({
    DataStatus? status,
    List<City>? cities,
    List<City>? visible,
    String? query,
    Failure? Function()? failure,
  }) {
    return CitiesState(
      status: status ?? this.status,
      cities: cities ?? this.cities,
      visible: visible ?? this.visible,
      query: query ?? this.query,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [status, cities, visible, query, failure];
}
