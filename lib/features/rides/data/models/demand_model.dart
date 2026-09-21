import '../../../../core/network/json_reader.dart';
import '../../../../core/types.dart';
import '../../../cities/data/models/city_model.dart';
import '../../domain/entities/route_demand.dart';

/// `GET /demand` and `GET /demand/top` (API.md §20).
abstract final class RouteDemandModel {
  static RouteDemand fromJson(Json json) {
    return RouteDemand(
      searches: json.integer('searches'),
      requests: json.integer('requests'),
      requestedSeats: json.integer('requested_seats'),
      activeRides: json.integer('active_rides'),
      seatsAvailable: json.integer('seats_available'),
      windowDays: json.integer('window_days', 7),
      // Present only on the `top` list — a single-route response is about a
      // route the caller already named.
      fromCity: CityModel.fromJsonOrNull(json.childOrNull('from_city')),
      toCity: CityModel.fromJsonOrNull(json.childOrNull('to_city')),
    );
  }
}

/// `GET /price-suggestion` (API.md §20).
abstract final class PriceSuggestionModel {
  static PriceSuggestion fromJson(Json json) {
    return PriceSuggestion(
      // `decimalOrNull` throughout: `suggested` is null when the server had
      // neither history nor coordinates, and a 0 fallback would show the
      // driver a price of zero manat.
      suggested: json.decimalOrNull('suggested'),
      min: json.decimalOrNull('min'),
      max: json.decimalOrNull('max'),
      source: PriceSource.fromApi(json.strOrNull('source')),
      sampleSize: json.integer('sample_size'),
      distanceKm: json.decimalOrNull('distance_km'),
      fuelEstimate: json.decimalOrNull('fuel_estimate'),
    );
  }
}
