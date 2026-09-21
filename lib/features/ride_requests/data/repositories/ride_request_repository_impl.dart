import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_envelope.dart';
import '../../domain/entities/ride_request.dart';
import '../../domain/repositories/ride_request_repository.dart';
import '../services/ride_request_api_service.dart';

class RideRequestRepositoryImpl implements RideRequestRepository {
  const RideRequestRepositoryImpl(this._api);

  final RideRequestApiService _api;

  @override
  FutureResult<Paginated<RideRequest>> mine({
    RideRequestStatus? status,
    int? page,
  }) => _api.mine(status: status, page: page);

  @override
  FutureResult<RideRequestWithMatches> create(RideRequestDraft draft) async {
    // The same guard the ride search uses: a route that ends where it starts
    // can never match anything, so it is not worth a round trip to be told so.
    if (!draft.isComplete) {
      return const Err(ValidationFailure(FailureCode.invalidInput));
    }
    return _api.create(draft);
  }

  @override
  FutureResult<RideRequestWithMatches> byId(int requestId) =>
      _api.byId(requestId);

  @override
  FutureResult<RideRequest> cancel(int requestId) => _api.cancel(requestId);

  @override
  FutureResult<Paginated<RideRequest>> incoming({
    int? fromCityId,
    int? toCityId,
    int? page,
  }) => _api.incoming(fromCityId: fromCityId, toCityId: toCityId, page: page);
}
