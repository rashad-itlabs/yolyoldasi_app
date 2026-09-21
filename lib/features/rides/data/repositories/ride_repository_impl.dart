import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_envelope.dart';
import '../../domain/entities/ride.dart';
import '../../domain/entities/ride_draft.dart';
import '../../domain/entities/ride_query.dart';
import '../../domain/repositories/ride_repository.dart';
import '../services/ride_api_service.dart';

class RideRepositoryImpl implements RideRepository {
  const RideRepositoryImpl(this._api);

  final RideApiService _api;

  @override
  FutureResult<Paginated<Ride>> search(
    RideSearchQuery query, {
    int? page,
  }) async {
    // A route is optional — without one the API lists every active ride, which
    // is what the passenger home browses. The single shape worth refusing here
    // is a route that ends where it starts: no ride can ever match it, and
    // asking would only spend a request to be told so.
    if (query.isSameCityRoute) {
      return const Err(ValidationFailure(FailureCode.invalidInput));
    }
    return _api.search(query, page: page);
  }

  @override
  FutureResult<Paginated<Ride>> mine({RideStatus? status, int? page}) =>
      _api.mine(status: status, page: page);

  @override
  FutureResult<Ride> byId(int rideId) => _api.byId(rideId);

  @override
  FutureResult<Ride> publish(RideDraft draft) => _api.publish(draft);

  @override
  FutureResult<Ride> update(int rideId, RideDraft draft) =>
      _api.update(rideId, draft);

  @override
  FutureResult<Ride> repeat(int rideId, DateTime departureAt, {int weeks = 1}) =>
      _api.repeat(rideId, departureAt, weeks: weeks);

  @override
  FutureResult<Ride> setStatus(int rideId, RideStatus status) =>
      _api.setStatus(rideId, status);

  @override
  FutureResult<void> cancel(int rideId) => _api.cancel(rideId);

  @override
  FutureResult<void> complete(int rideId) => _api.complete(rideId);

}
