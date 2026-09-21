import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/route_demand.dart';
import '../models/demand_model.dart';

/// `/demand` and `/price-suggestion` — API.md §20.
class DemandApiService {
  const DemandApiService(this._client);

  final ApiClient _client;

  FutureResult<RouteDemand> forRoute({
    required int fromCityId,
    required int toCityId,
  }) => _client.getObject(
    Api.demand,
    query: {'from_city_id': fromCityId, 'to_city_id': toCityId},
    parse: RouteDemandModel.fromJson,
  );

  /// The city is *not* sent: the server reads it from the driver's own profile,
  /// so the app cannot accidentally ask for a region the driver never visits.
  FutureResult<List<RouteDemand>> topRoutes() =>
      _client.getList(Api.demandTop, parse: RouteDemandModel.fromJson);

  FutureResult<PriceSuggestion> priceFor({
    required int fromCityId,
    required int toCityId,
  }) => _client.getObject(
    Api.priceSuggestion,
    query: {'from_city_id': fromCityId, 'to_city_id': toCityId},
    parse: PriceSuggestionModel.fromJson,
  );
}
