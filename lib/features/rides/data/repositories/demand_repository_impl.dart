import '../../../../core/error/result.dart';
import '../../domain/entities/route_demand.dart';
import '../../domain/repositories/demand_repository.dart';
import '../services/demand_api_service.dart';

class DemandRepositoryImpl implements DemandRepository {
  const DemandRepositoryImpl(this._api);

  final DemandApiService _api;

  @override
  FutureResult<RouteDemand> forRoute({
    required int fromCityId,
    required int toCityId,
  }) => _api.forRoute(fromCityId: fromCityId, toCityId: toCityId);

  @override
  FutureResult<List<RouteDemand>> topRoutes() => _api.topRoutes();

  @override
  FutureResult<PriceSuggestion> priceFor({
    required int fromCityId,
    required int toCityId,
  }) => _api.priceFor(fromCityId: fromCityId, toCityId: toCityId);
}
