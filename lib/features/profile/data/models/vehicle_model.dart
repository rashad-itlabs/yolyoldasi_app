import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/json_reader.dart';
import '../../../../core/types.dart';
import '../../domain/entities/vehicle.dart';

/// `/vehicles` (API.md §8), and the `vehicle` block embedded in rides and in
/// the driver profile.
abstract final class VehicleModel {
  static Vehicle fromJson(Json json) {
    return Vehicle(
      id: json.integer('id'),
      brand: json.str('brand'),
      model: json.str('model'),
      color: json.strOrNull('color'),
      // API.md §9: absent unless the reader is the driver, so this is the one
      // field that legitimately comes back missing on a well-formed response.
      plate: json.strOrNull('plate'),
      year: json.integerOrNull('year'),
      seats: json.integer('seats', AppRules.defaultVehicleSeats),
    );
  }

  static Vehicle? fromJsonOrNull(Json? json) {
    if (json == null || json.isEmpty) return null;
    final id = json.integerOrNull('id');
    return id == null ? null : fromJson(json);
  }

  /// Body for `POST /vehicles` and `PUT /vehicles/{id}`.
  ///
  /// `brand` and `model` are required; the rest are optional and are sent as
  /// explicit nulls when cleared, since PUT replaces the record.
  static Json toJson(Vehicle vehicle) => {
    'brand': vehicle.brand.trim(),
    'model': vehicle.model.trim(),
    'color': _blankToNull(vehicle.color),
    'plate': _blankToNull(vehicle.plate),
    'year': vehicle.year,
    'seats': vehicle.seats,
  };

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
