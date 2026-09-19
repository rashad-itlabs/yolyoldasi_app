import '../../../../core/error/result.dart';
import '../../../../core/network/api_envelope.dart';
import '../../domain/entities/booking.dart';
import '../../domain/repositories/booking_repository.dart';
import '../services/booking_api_service.dart';

class BookingRepositoryImpl implements BookingRepository {
  const BookingRepositoryImpl(this._api);

  final BookingApiService _api;

  @override
  FutureResult<Booking> request(int rideId, BookingRequest body) =>
      _api.request(rideId, body);

  @override
  FutureResult<Paginated<Booking>> mine({BookingStatus? status, int? page}) =>
      _api.mine(status: status, page: page);

  @override
  FutureResult<Paginated<Booking>> incoming({
    BookingStatus? status,
    int? page,
  }) => _api.incoming(status: status, page: page);

  @override
  FutureResult<Booking> byId(int bookingId) => _api.byId(bookingId);

  @override
  FutureResult<Booking> confirm(int bookingId) => _api.confirm(bookingId);

  @override
  FutureResult<Booking> reject(int bookingId) => _api.reject(bookingId);

  @override
  FutureResult<Booking> cancel(int bookingId, {String? reason}) =>
      _api.cancel(bookingId, reason: reason);

  @override
  FutureResult<Booking> blockPassenger(int bookingId) =>
      _api.blockPassenger(bookingId);

  @override
  FutureResult<Booking> unblockPassenger(int bookingId) =>
      _api.unblockPassenger(bookingId);
}
