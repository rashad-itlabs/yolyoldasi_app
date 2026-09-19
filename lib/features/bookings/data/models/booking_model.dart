import '../../../../core/network/json_reader.dart';
import '../../../../core/types.dart';
import '../../../profile/data/models/user_model.dart';
import '../../../rides/data/models/ride_model.dart';
import '../../domain/entities/booking.dart';

/// The booking object in API.md §10.
abstract final class BookingModel {
  static Booking fromJson(Json json) {
    return Booking(
      id: json.integer('id'),
      ride: RideModel.fromJson(json.child('ride')),
      passenger: PublicUserModel.fromJsonOrNull(json.childOrNull('passenger')),
      driver: PublicUserModel.fromJsonOrNull(json.childOrNull('driver')),
      seats: json.integer('seats', 1),
      totalPrice: json.decimal('total_price'),
      status: BookingStatus.fromApi(json.strOrNull('status')),
      createdAt: json.date('created_at'),
      message: json.str('message'),
      decidedAt: json.dateOrNull('decided_at'),
      cancelledAt: json.dateOrNull('cancelled_at'),
      cancellationReason: json.strOrNull('cancellation_reason'),
      passengerReviewed: json.flag('passenger_reviewed'),
      driverReviewed: json.flag('driver_reviewed'),
      conversationId: json.integerOrNull('conversation_id'),
      // The driver's answer to a cancellation: this ride is shut to this
      // passenger. Absent on older responses, which read as "not blocked".
      passengerBlocked: json.flag('passenger_blocked'),
      // Present only while the booking is confirmed or completed; the key is
      // absent otherwise, not null (API.md §10).
      contactPhone: json.strOrNull('contact_phone'),
    );
  }

  /// Body for `POST /rides/{id}/bookings`.
  static Json requestBody(BookingRequest request) => {
    'seats': request.seats,
    'message': ?_blankToNull(request.message),
  };

  /// Body for `POST /bookings/{id}/cancel` — the reason is optional, ≤255.
  static Json cancelBody(String? reason) => {
    'reason': ?_blankToNull(reason ?? ''),
  };

  static String? _blankToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
