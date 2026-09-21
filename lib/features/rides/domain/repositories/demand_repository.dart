import '../../../../core/error/result.dart';
import '../entities/route_demand.dart';

/// What passengers are looking for, and what a route usually costs — API.md §20.
abstract interface class DemandRepository {
  /// `GET /demand` — one route's supply-and-demand picture.
  FutureResult<RouteDemand> forRoute({
    required int fromCityId,
    required int toCityId,
  });

  /// `GET /demand/top` — the routes worth publishing on, near the driver.
  ///
  /// Ranked by *unmet* demand, not raw search volume: Baku–Sumqayit is searched
  /// constantly and already has plenty of listings, so suggesting one more
  /// there helps nobody.
  FutureResult<List<RouteDemand>> topRoutes();

  /// `GET /price-suggestion`.
  FutureResult<PriceSuggestion> priceFor({
    required int fromCityId,
    required int toCityId,
  });
}
