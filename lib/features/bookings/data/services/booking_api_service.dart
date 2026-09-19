import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_envelope.dart';
import '../../domain/entities/booking.dart';
import '../models/booking_model.dart';

/// `/bookings` and `/rides/{id}/bookings` — API.md §10.
class BookingApiService {
  const BookingApiService(this._client);

  final ApiClient _client;

  /// `POST /rides/{id}/bookings`
  ///
  /// Answers 201 with a `conversation_id`: the thread opens with the booking,
  /// before the driver has decided. A **409** means this ride has already been
  /// applied to — permanently, even after a cancellation (API.md §10).
  FutureResult<Booking> request(int rideId, BookingRequest body) =>
      _client.post(
        Api.rideBookings(rideId),
        body: BookingModel.requestBody(body),
        parse: BookingModel.fromJson,
      );

  /// `GET /bookings` — the signed-in user's bookings as a passenger.
  FutureResult<Paginated<Booking>> mine({BookingStatus? status, int? page}) =>
      _client.getPage(
        Api.bookings,
        query: {'status': ?status?.apiValue},
        page: page,
        parse: BookingModel.fromJson,
      );

  /// `GET /bookings/incoming` — requests on the signed-in user's own rides.
  FutureResult<Paginated<Booking>> incoming({
    BookingStatus? status,
    int? page,
  }) => _client.getPage(
    Api.bookingsIncoming,
    query: {'status': ?status?.apiValue},
    page: page,
    parse: BookingModel.fromJson,
  );

  FutureResult<Booking> byId(int bookingId) =>
      _client.getObject(Api.booking(bookingId), parse: BookingModel.fromJson);

  /// Driver only. 422 when already decided, or when the seats have gone.
  FutureResult<Booking> confirm(int bookingId) =>
      _client.post(Api.bookingConfirm(bookingId), parse: BookingModel.fromJson);

  /// Driver only. Also locks the conversation.
  FutureResult<Booking> reject(int bookingId) =>
      _client.post(Api.bookingReject(bookingId), parse: BookingModel.fromJson);

  /// Either side. A confirmed booking releases its seats back to the ride.
  FutureResult<Booking> cancel(int bookingId, {String? reason}) => _client.post(
    Api.bookingCancel(bookingId),
    body: BookingModel.cancelBody(reason),
    parse: BookingModel.fromJson,
  );

  /// Driver only. The answer to a passenger who cancelled: this ride is shut
  /// to them, so their next request is a 409 rather than a new booking.
  FutureResult<Booking> blockPassenger(int bookingId) =>
      _client.post(Api.bookingBlock(bookingId), parse: BookingModel.fromJson);

  /// Driver only. Reopens the ride to that passenger.
  FutureResult<Booking> unblockPassenger(int bookingId) =>
      _client.post(Api.bookingUnblock(bookingId), parse: BookingModel.fromJson);
}
