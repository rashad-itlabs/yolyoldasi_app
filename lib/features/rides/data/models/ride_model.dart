import '../../../../core/network/json_reader.dart';
import '../../../../core/types.dart';
import '../../../cities/data/models/city_model.dart';
import '../../../profile/data/models/user_model.dart';
import '../../../profile/data/models/vehicle_model.dart';
import '../../../profile/domain/entities/app_user.dart';
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
      womenOnly: json.flag('women_only'),
      isBoosted: json.flag('is_boosted'),
      shareUrl: json.strOrNull('share_url'),
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
    'women_only': draft.womenOnly,
    // Sent only when it means something. `1` is the default on both sides, and
    // an extra key on every publish would suggest the form always fans out.
    if (draft.repeatWeeks > 1) 'repeat_weeks': draft.repeatWeeks,
  };

  /// Body for `POST /rides/{id}/repeat` — the same run, a new date.
  static Json repeatBody({required DateTime departureAt, int weeks = 1}) => {
    'departure_at': departureAt.toIso8601String(),
    if (weeks > 1) 'repeat_weeks': weeks,
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
    'women_only': draft.womenOnly,
    'status': ?status?.apiValue,
  };
}
