import '../../../../core/error/result.dart';
import '../entities/city.dart';

/// The 54 Azerbaijani cities the marketplace covers.
abstract interface class CityRepository {
  /// Every city, ordered by name. Cached after the first successful read —
  /// API.md §6 notes the list rarely changes and asks the client to keep it.
  FutureResult<List<City>> all();

  /// A city by id, from the cache when it is warm. Used to resolve the ids the
  /// search form and the publish form carry around.
  City? byId(int? id);

  /// Cities matching [query], popular ones first then alphabetical. Returns
  /// `null` while the list has not been loaded yet.
  List<City>? search(String query, String languageCode);

  /// Drops the cache so the next [all] hits the network.
  void invalidate();
}
