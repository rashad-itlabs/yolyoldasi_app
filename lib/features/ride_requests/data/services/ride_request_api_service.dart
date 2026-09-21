import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_envelope.dart';
import '../../../../core/types.dart';
import '../../../rides/data/models/ride_model.dart';
import '../../domain/entities/ride_request.dart';
import '../../domain/repositories/ride_request_repository.dart';
import '../models/ride_request_model.dart';

/// `/ride-requests` — API.md §19.
class RideRequestApiService {
  const RideRequestApiService(this._client);

  final ApiClient _client;

  FutureResult<Paginated<RideRequest>> mine({
    RideRequestStatus? status,
    int? page,
  }) => _client.getPage(
    Api.rideRequests,
    query: {'status': ?status?.apiValue},
    page: page,
    parse: RideRequestModel.fromJson,
  );

  /// `POST /ride-requests` → 201, with whatever already matches.
  ///
  /// Posting the same route and date twice updates the existing row instead of
  /// failing, so there is no duplicate case to handle here.
  FutureResult<RideRequestWithMatches> create(RideRequestDraft draft) =>
      _client.postFull(
        Api.rideRequests,
        body: RideRequestModel.createBody(draft),
        parse: _withMatches,
      );

  FutureResult<RideRequestWithMatches> byId(int requestId) =>
      _client.getFull(Api.rideRequest(requestId), parse: _withMatches);

  /// `DELETE /ride-requests/{id}` — the row survives as `cancelled`.
  FutureResult<RideRequest> cancel(int requestId) => _client.delete(
    Api.rideRequest(requestId),
    parse: RideRequestModel.fromJson,
  );

  FutureResult<Paginated<RideRequest>> incoming({
    int? fromCityId,
    int? toCityId,
    int? page,
  }) => _client.getPage(
    Api.rideRequestsIncoming,
    query: {'from_city_id': ?fromCityId, 'to_city_id': ?toCityId},
    page: page,
    parse: RideRequestModel.fromJson,
  );

  /// Splits the two halves of the body: the request itself sits in `data`, the
  /// rides that match it in `matches`.
  static RideRequestWithMatches _withMatches(Json body) {
    final matches = body['matches'];

    return (
      request: RideRequestModel.fromJson(Envelope.object(body)),
      // An older server simply will not send the key. An empty list is the
      // right reading of that: "nothing matched yet", which is also what the
      // screen shows when the list really is empty.
      matches: matches is List
          ? matches
                .whereType<Map>()
                .map((row) => RideModel.fromJson(Json.from(row)))
                .toList(growable: false)
          : const [],
    );
  }
}
