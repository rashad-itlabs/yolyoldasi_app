import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_envelope.dart';
import '../../domain/entities/recent_search.dart';
import '../../domain/entities/ride.dart';
import '../../domain/entities/ride_draft.dart';
import '../../domain/entities/ride_query.dart';
import '../models/ride_model.dart';

/// `/rides` and `/me/recent-searches` — API.md §9 and §14.
class RideApiService {
  const RideApiService(this._client);

  final ApiClient _client;

  /// `GET /rides` — 20 per page. Every call is also recorded as a recent
  /// search server-side.
  FutureResult<Paginated<Ride>> search(RideSearchQuery query, {int? page}) =>
      _client.getPage(
        Api.rides,
        query: query.toQueryParameters(),
        page: page,
        parse: RideModel.fromJson,
      );

  /// `GET /rides/mine` — the driver's own listings, newest departure first.
  FutureResult<Paginated<Ride>> mine({RideStatus? status, int? page}) =>
      _client.getPage(
        Api.ridesMine,
        query: {'status': ?status?.apiValue},
        page: page,
        parse: RideModel.fromJson,
      );

  FutureResult<Ride> byId(int rideId) =>
      _client.getObject(Api.ride(rideId), parse: RideModel.fromJson);

  /// `POST /rides` — 422 without a driver profile, or with somebody else's car.
  FutureResult<Ride> publish(RideDraft draft) => _client.post(
    Api.rides,
    body: RideModel.createBody(draft),
    parse: RideModel.fromJson,
  );

  /// `PUT /rides/{id}` — only an `active` ride is editable, and `total_seats`
  /// may not drop below `booked_seats`.
  FutureResult<Ride> update(
    int rideId,
    RideDraft draft, {
    RideStatus? status,
  }) => _client.put(
    Api.ride(rideId),
    body: RideModel.updateBody(draft, status: status),
    parse: RideModel.fromJson,
  );

  /// Flips between `active` and `inactive` without touching anything else.
  FutureResult<Ride> setStatus(int rideId, RideStatus status) => _client.put(
    Api.ride(rideId),
    body: {'status': status.apiValue},
    parse: RideModel.fromJson,
  );

  /// `DELETE /rides/{id}` — a cancellation, not a delete. Every pending and
  /// confirmed booking is cancelled with it and the passengers are notified.
  FutureResult<void> cancel(int rideId) =>
      _client.send('DELETE', Api.ride(rideId));

  /// `POST /rides/{id}/complete` — 422 while departure is still in the future.
  FutureResult<void> complete(int rideId) =>
      _client.send('POST', Api.rideComplete(rideId));

  FutureResult<List<RecentSearch>> recentSearches() =>
      _client.getList(Api.meRecentSearches, parse: RecentSearchModel.fromJson);

  FutureResult<void> clearRecentSearches() =>
      _client.send('DELETE', Api.meRecentSearches);
}
