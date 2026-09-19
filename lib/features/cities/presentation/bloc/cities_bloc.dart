import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/bloc/data_status.dart';
import '../../../../core/constants/az_cities.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/city.dart';
import '../../domain/repositories/city_repository.dart';

part 'cities_event.dart';
part 'cities_state.dart';

/// Backs every city picker in the app.
///
/// Provided once above the router rather than per screen: the list is the same
/// everywhere, it is cached in the repository anyway, and the search form needs
/// it resolved before it can render the route the user last used.
class CitiesBloc extends Bloc<CitiesEvent, CitiesState> {
  CitiesBloc({required CityRepository cities})
    : _cities = cities,
      super(const CitiesState()) {
    on<CitiesRequested>(_onRequested);
    on<CitiesRefreshed>(_onRefreshed);
    on<CitiesQueryChanged>(_onQueryChanged);
  }

  final CityRepository _cities;

  Future<void> _onRequested(
    CitiesRequested event,
    Emitter<CitiesState> emit,
  ) async {
    if (state.status.isSuccess || state.status.isBusy) return;
    await _load(emit, refreshing: false);
  }

  Future<void> _onRefreshed(
    CitiesRefreshed event,
    Emitter<CitiesState> emit,
  ) async {
    _cities.invalidate();
    await _load(emit, refreshing: state.cities.isNotEmpty);
  }

  Future<void> _load(
    Emitter<CitiesState> emit, {
    required bool refreshing,
  }) async {
    emit(
      state.copyWith(
        status: refreshing ? DataStatus.refreshing : DataStatus.loading,
        failure: () => null,
      ),
    );

    final result = await _cities.all();
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            status: DataStatus.success,
            cities: value,
            visible: _filter(value, state.query, _languageCode),
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(status: DataStatus.failure, failure: () => failure),
        );
    }
  }

  void _onQueryChanged(CitiesQueryChanged event, Emitter<CitiesState> emit) {
    _languageCode = event.languageCode;
    emit(
      state.copyWith(
        query: event.query,
        visible: _filter(state.cities, event.query, event.languageCode),
      ),
    );
  }

  /// Remembered so a reload re-applies the filter in the language the picker
  /// was last shown in.
  String _languageCode = 'az';

  static List<City> _filter(
    List<City> cities,
    String query,
    String languageCode,
  ) {
    final folded = AzCity.foldQuery(query);
    final results = cities
        .where((city) => city.matches(folded, languageCode))
        .toList();
    results.sort((a, b) => City.compareForPicker(a, b, languageCode));
    return results;
  }
}
