import '../../../../core/network/json_reader.dart';
import '../../../../core/types.dart';
import '../../domain/entities/city.dart';

/// `{ "id": 1, "name": "Bakı" }` — API.md §6.
///
/// Cities are also embedded in rides (`from_city`, `to_city`), in `/me`
/// (`city`, nullable) and in recent searches, so this parser is shared.
abstract final class CityModel {
  static City fromJson(Json json) =>
      City(id: json.integer('id'), name: json.str('name'));

  /// The embedded form, which is absent rather than null when the user has no
  /// city set (API.md §16.5).
  static City? fromJsonOrNull(Json? json) {
    if (json == null || json.isEmpty) return null;
    final id = json.integerOrNull('id');
    if (id == null) return null;
    return City(id: id, name: json.str('name'));
  }
}
