import '../../../../core/network/json_reader.dart';
import '../../../../core/types.dart';
import '../../../cities/data/models/city_model.dart';
import '../../../profile/data/models/user_model.dart';
import '../../domain/entities/ride_request.dart';

/// The ride-request object in API.md §19.
abstract final class RideRequestModel {
  static RideRequest fromJson(Json json) {
    return RideRequest(
      id: json.integer('id'),
      passenger: PublicUserModel.fromJsonOrNull(json.childOrNull('passenger')),
      fromCity: CityModel.fromJson(json.child('from_city')),
      toCity: CityModel.fromJson(json.child('to_city')),
      wantedDate: _parseDate(json.strOrNull('wanted_date')) ?? DateTime.now(),
      flexibleDays: json.integer('flexible_days'),
      seats: json.integer('seats', 1),
      note: json.str('note'),
      status: RideRequestStatus.fromApi(json.strOrNull('status')),
      isMine: json.flag('is_mine'),
      matchedRideId: json.integerOrNull('matched_ride_id'),
      createdAt: json.date('created_at'),
    );
  }

  /// Body for `POST /ride-requests`.
  static Json createBody(RideRequestDraft draft) => {
    'from_city_id': draft.fromCityId,
    'to_city_id': draft.toCityId,
    'wanted_date': formatDate(draft.wantedDate!),
    'flexible_days': draft.flexibleDays,
    'seats': draft.seats,
    if (draft.note.trim().isNotEmpty) 'note': draft.note.trim(),
  };

  /// `YYYY-MM-DD`, the one shape that is not ISO 8601 (API.md §1).
  static String formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  /// Parsed as a *local* date rather than through `DateTime.parse`, which would
  /// read a bare `YYYY-MM-DD` as UTC midnight and shift the day backwards for
  /// anyone west of Greenwich, which would move the request a day.
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
