import 'package:equatable/equatable.dart';

import '../../../cities/domain/entities/city.dart';

/// How busy one route is — API.md §20.
///
/// This is the number a driver never had. Publishing used to be a shot in the
/// dark: `GET /rides` showed supply and nothing showed demand, even though the
/// server had been recording every search all along.
///
/// Two signals, kept apart on purpose. [searches] is weak but plentiful — it
/// says how big the route is. [requests] is strong but scarce — it says how
/// serious the people on it are.
class RouteDemand extends Equatable {
  const RouteDemand({
    this.searches = 0,
    this.requests = 0,
    this.requestedSeats = 0,
    this.activeRides = 0,
    this.seatsAvailable = 0,
    this.windowDays = 7,
    this.fromCity,
    this.toCity,
  });

  /// Distinct people who searched this route in the last [windowDays].
  final int searches;

  /// Open ride requests on it.
  final int requests;

  /// Seats those requests add up to.
  final int requestedSeats;

  final int activeRides;
  final int seatsAvailable;
  final int windowDays;

  /// Only filled on the `top` list, where the route is the row's subject rather
  /// than something the caller already knows.
  final City? fromCity;
  final City? toCity;

  static const RouteDemand empty = RouteDemand();

  /// Whether there is enough here to say anything at all.
  ///
  /// Below this, a demand line would be noise: "2 people searched" reads as
  /// "nobody wants this" and talks the driver out of a route rather than into
  /// it. Saying nothing is the better of the two.
  bool get isWorthShowing => searches >= 5 || requests > 0;

  /// Demand that the seats already on offer cannot absorb.
  bool get isUnderserved => requestedSeats > seatsAvailable || activeRides == 0;

  @override
  List<Object?> get props => [
    searches,
    requests,
    requestedSeats,
    activeRides,
    seatsAvailable,
    windowDays,
    fromCity,
    toCity,
  ];
}

/// Where a suggested price came from (API.md §20).
enum PriceSource {
  /// The median of real listings on this route — the market's own answer.
  history('history'),

  /// Distance × a per-kilometre rate, when the route has no history yet.
  distance('distance'),

  /// Neither. The app shows nothing at all in this case.
  none('none');

  const PriceSource(this.apiValue);

  final String apiValue;

  static PriceSource fromApi(String? value) => PriceSource.values.firstWhere(
    (s) => s.apiValue == value,
    orElse: () => PriceSource.none,
  );
}

/// What to charge, and what the trip costs to drive — API.md §20.
///
/// The first-time driver gets stuck here more than anywhere else on the form.
/// Price too high and nobody books, and they never come back; too low and they
/// do not cover the fuel. Both end in a lost driver.
class PriceSuggestion extends Equatable {
  const PriceSuggestion({
    this.suggested,
    this.min,
    this.max,
    this.source = PriceSource.none,
    this.sampleSize = 0,
    this.distanceKm,
    this.fuelEstimate,
  });

  /// Null when the server had nothing to go on. The form then shows no hint —
  /// an invented number is worse than silence, because the driver would trust
  /// it.
  final double? suggested;

  final double? min;
  final double? max;

  final PriceSource source;

  /// How many listings the median came from. Only meaningful for
  /// [PriceSource.history].
  final int sampleSize;

  final double? distanceKm;

  /// Rough fuel cost for the whole trip, in manat. The comparison that makes
  /// the earnings line land: "3 seats × 15 ₼ = 45 ₼, fuel about 22 ₼".
  final double? fuelEstimate;

  static const PriceSuggestion none = PriceSuggestion();

  bool get hasSuggestion => suggested != null;

  bool get hasRange => min != null && max != null && min != max;

  @override
  List<Object?> get props => [
    suggested,
    min,
    max,
    source,
    sampleSize,
    distanceKm,
    fuelEstimate,
  ];
}
