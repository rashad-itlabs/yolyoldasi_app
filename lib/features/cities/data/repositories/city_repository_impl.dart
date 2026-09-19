import '../../../../core/constants/az_cities.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/city.dart';
import '../../domain/repositories/city_repository.dart';
import '../services/city_api_service.dart';

/// Caches the city list for the process lifetime.
///
/// Every screen that names a place — the pickers, ride cards, the profile —
/// reads it, and API.md §6 says it rarely changes, so one fetch per launch is
/// the right trade. The synchronous [byId] and [search] are what let the
/// pickers filter without an await per keystroke.
class CityRepositoryImpl implements CityRepository {
  CityRepositoryImpl(this._api);

  final CityApiService _api;

  List<City>? _cities;
  Map<int, City>? _byId;

  /// De-duplicates concurrent first reads: the search form and the profile
  /// screen both ask on the first frame, and one `GET /cities` should serve
  /// both.
  Future<Result<List<City>>>? _inFlight;

  @override
  FutureResult<List<City>> all() {
    final cached = _cities;
    if (cached != null) return Future.value(Ok(cached));
    return _inFlight ??= _fetch();
  }

  Future<Result<List<City>>> _fetch() async {
    final result = await _api.list();
    _inFlight = null;
    if (result case Ok(:final value)) _cache(value);
    return result;
  }

  void _cache(List<City> cities) {
    _cities = cities;
    _byId = {for (final city in cities) city.id: city};
  }

  @override
  City? byId(int? id) => id == null ? null : _byId?[id];

  @override
  List<City>? search(String query, String languageCode) {
    final cities = _cities;
    if (cities == null) return null;

    final folded = AzCity.foldQuery(query);
    final results = cities
        .where((city) => city.matches(folded, languageCode))
        .toList();
    results.sort((a, b) => City.compareForPicker(a, b, languageCode));
    return results;
  }

  @override
  void invalidate() {
    _cities = null;
    _byId = null;
  }
}
