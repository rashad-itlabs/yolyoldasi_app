import '../../../../core/network/json_reader.dart';
import '../../../../core/types.dart';
import '../../../cities/data/models/city_model.dart';
import '../../../profile/data/models/user_model.dart';
import '../../../profile/data/models/vehicle_model.dart';
import '../../../profile/domain/entities/app_user.dart';
import '../../domain/entities/recent_search.dart';
import '../../domain/entities/ride.dart';
import '../../domain/entities/ride_draft.dart';

/// The ride object in API.md §9.
abstract final class RideModel {
  static Ride fromJson(Json json) {
    final totalSeats = json.integer('total_seats');
    final bookedSeats = json.integer('booked_seats');

    return Ride(
      id: json.integer('id'),
      driver:
          PublicUserModel.fromJsonOrNull(json.childOrNull('driver')) ??
          const PublicUser(id: 0),
      vehicle: VehicleModel.fromJsonOrNull(json.childOrNull('vehicle')),
      fromCity: CityModel.fromJson(json.child('from_city')),
      toCity: CityModel.fromJson(json.child('to_city')),
      departureAt: json.date('departure_at'),
      totalSeats: totalSeats,
      bookedSeats: bookedSeats,
      // Trust the server's figure (API.md §16.3); the subtraction is only a
      // fallback for a response that omitted the key entirely.
      seatsLeft: json.integerOrNull('seats_left') ?? (totalSeats - bookedSeats),
      pricePerSeat: json.decimal('price_per_seat'),
      status: RideStatus.fromApi(json.strOrNull('status')),
      createdAt: json.date('created_at'),
      note: json.str('note'),
      pickupPoint: json.str('pickup_point'),
      dropoffPoint: json.str('dropoff_point'),
      instantBooking: json.flag('instant_booking'),
      isMine: json.flag('is_mine'),
    );
  }

  /// Body for `POST /rides`. Every required field is asserted by [RideDraft],
  /// so this is only reached with a complete draft.
  static Json createBody(RideDraft draft) => {
    'vehicle_id': draft.vehicleId,
    'from_city_id': draft.fromCityId,
    'to_city_id': draft.toCityId,
    'departure_at': draft.departureAt!.toIso8601String(),
    'total_seats': draft.totalSeats,
    'price_per_seat': draft.pricePerSeat,
    'note': draft.note.trim(),
    'pickup_point': draft.pickupPoint.trim(),
    'dropoff_point': draft.dropoffPoint.trim(),
    'instant_booking': draft.instantBooking,
  };

  /// Body for `PUT /rides/{id}`.
  ///
  /// Route and vehicle are missing on purpose: API.md §9 lists exactly which
  /// fields an edit may touch, and those two are not among them.
  static Json updateBody(RideDraft draft, {RideStatus? status}) => {
    'departure_at': ?draft.departureAt?.toIso8601String(),
    'total_seats': draft.totalSeats,
    'price_per_seat': draft.pricePerSeat,
    'note': draft.note.trim(),
    'pickup_point': draft.pickupPoint.trim(),
    'dropoff_point': draft.dropoffPoint.trim(),
    'instant_booking': draft.instantBooking,
    'status': ?status?.apiValue,
  };
}

/// `GET /me/recent-searches` (API.md §14).
abstract final class RecentSearchModel {
  static RecentSearch fromJson(Json json) {
    return RecentSearch(
      fromCity: CityModel.fromJson(json.child('from_city')),
      toCity: CityModel.fromJson(json.child('to_city')),
      searchedDate: _parseDate(json.strOrNull('searched_date')),
      seats: json.integer('seats', 1),
      searchedAt: json.date('searched_at'),
    );
  }

  /// `searched_date` is `YYYY-MM-DD`, not ISO 8601 — parsing it as a local date
  /// keeps "tomorrow" from drifting a day under a negative UTC offset.
  static DateTime? _parseDate(String? value) {
    if (value == null) return null;
    final parts = value.split('-');
    if (parts.length != 3) return DateTime.tryParse(value);
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }
}
