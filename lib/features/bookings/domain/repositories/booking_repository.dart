import '../../../../core/error/result.dart';
import '../../../../core/network/api_envelope.dart';
import '../entities/booking.dart';

/// Seat reservations — API.md §10.
abstract interface class BookingRepository {
  /// `POST /rides/{id}/bookings`.
  ///
  /// Fails with a [ConflictFailure] when the user has already applied to this
  /// ride; API.md §16.4 asks for that case to be surfaced differently from a
  /// validation error, so callers should check `failure.isDuplicate`.
  FutureResult<Booking> request(int rideId, BookingRequest body);

  /// `GET /bookings` — as a passenger.
  FutureResult<Paginated<Booking>> mine({BookingStatus? status, int? page});

  /// `GET /bookings/incoming` — as a driver.
  FutureResult<Paginated<Booking>> incoming({BookingStatus? status, int? page});

  FutureResult<Booking> byId(int bookingId);

  /// Driver only.
  FutureResult<Booking> confirm(int bookingId);

  /// Driver only. Locks the conversation.
  FutureResult<Booking> reject(int bookingId);

  /// Either side, while the ride has not departed.
  FutureResult<Booking> cancel(int bookingId, {String? reason});

  /// `POST /bookings/{id}/block` — driver only.
  ///
  /// Shuts the ride to a passenger who cancelled, so the re-booking the API
  /// otherwise allows comes back as a [ConflictFailure] instead.
  FutureResult<Booking> blockPassenger(int bookingId);

  /// `POST /bookings/{id}/unblock` — driver only. Undoes [blockPassenger].
  FutureResult<Booking> unblockPassenger(int bookingId);
}
