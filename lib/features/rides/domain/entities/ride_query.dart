import 'package:equatable/equatable.dart';

import '../../../../core/types.dart';
import '../../../profile/domain/entities/user_enums.dart';
import 'ride.dart';

/// `sort` on `GET /rides` (API.md §9).
enum RideSortOption {
  earliest('departure_at'),
  cheapest('price_per_seat');

  const RideSortOption(this.apiValue);

  final String apiValue;

  static const RideSortOption fallback = RideSortOption.earliest;

  static RideSortOption fromApi(String? value) => RideSortOption.values
      .firstWhere((o) => o.apiValue == value, orElse: () => fallback);
}

/// Broad departure windows, easier to reason about than a time slider.
enum TimeOfDayBand {
  morning(6, 12),
  afternoon(12, 17),
  evening(17, 22),
  night(22, 6);

  const TimeOfDayBand(this.startHour, this.endHour);

  final int startHour;
  final int endHour;

  bool contains(DateTime time) {
    final hour = time.hour;
    // `night` wraps around midnight.
    if (startHour <= endHour) return hour >= startHour && hour < endHour;
    return hour >= startHour || hour < endHour;
  }
}

/// Everything the passenger typed into the search form.
///
/// Split deliberately in two: [toQueryParameters] is what `GET /rides` accepts,
/// and [refine] is the rest. The API has no price ceiling or departure-window
/// parameter, so those two narrow the results already loaded rather than the
/// query — which is why the filter sheet describes them as refining the list.
class RideSearchQuery extends Equatable {
  const RideSearchQuery({
    this.fromCityId,
    this.toCityId,
    this.date,
    this.seats = 1,
    this.sort = RideSortOption.earliest,
    this.maxPrice,
    this.bands = const <TimeOfDayBand>{},
    this.driverGender,
    this.womenOnly = false,
    this.instantOnly = false,
    this.verifiedOnly = false,
  });

  /// Both are optional on the wire: with neither, `GET /rides` answers with
  /// every active ride, which is what the browse list on the passenger home
  /// asks for. The search *form* is stricter — it keeps its button disabled
  /// until both are picked ([hasRoute]).
  final int? fromCityId;
  final int? toCityId;

  /// `null` means "any date from now on".
  final DateTime? date;

  /// 1–4. Only rides with at least this many free seats come back.
  final int seats;

  final RideSortOption sort;

  // ---- server-side filters -----------------------------------------------
  /// Only rides driven by someone of this gender.
  ///
  /// The reason this exists is narrow and specific: for a woman travelling
  /// alone between cities, the deciding question is who is behind the wheel.
  /// Without the filter that whole group stays outside the app.
  final Gender? driverGender;

  /// Only rides the driver marked women-only.
  final bool womenOnly;

  /// Only rides that confirm on the spot — no waiting on an answer.
  final bool instantOnly;

  /// Only drivers whose documents are approved.
  final bool verifiedOnly;

  // ---- client-side refinements -------------------------------------------
  final double? maxPrice;
  final Set<TimeOfDayBand> bands;

  /// The search form's own rule: a route needs two different cities.
  bool get hasRoute =>
      fromCityId != null && toCityId != null && fromCityId != toCityId;

  /// Nothing narrowed at all — the browse list's query.
  bool get isUnfiltered => fromCityId == null && toCityId == null;

  /// The one route shape no ride can match. The form can produce it for a
  /// moment while the user swaps the two ends around.
  bool get isSameCityRoute => fromCityId != null && fromCityId == toCityId;

  int get activeFilterCount =>
      (maxPrice != null ? 1 : 0) +
      bands.length +
      (sort != RideSortOption.earliest ? 1 : 0) +
      (driverGender != null ? 1 : 0) +
      (womenOnly ? 1 : 0) +
      (instantOnly ? 1 : 0) +
      (verifiedOnly ? 1 : 0);

  bool get hasRefinements => maxPrice != null || bands.isNotEmpty;

  /// The query string for `GET /rides`. A city is sent only once the user has
  /// picked one: leaving both out is how the browse list asks for every active
  /// ride rather than one route's worth.
  Json toQueryParameters() => {
    'from_city_id': ?fromCityId,
    'to_city_id': ?toCityId,
    'date': ?_formatDate(date),
    'seats': seats,
    'sort': sort.apiValue,
    'driver_gender': ?driverGender?.apiValue,
    // Only sent when on: `women_only=0` would read as an explicit "show me
    // rides that are not women-only", which is not what an unchecked box means.
    if (womenOnly) 'women_only': 1,
    if (instantOnly) 'instant_only': 1,
    if (verifiedOnly) 'verified_only': 1,
  };

  /// `YYYY-MM-DD` — the one field that is not ISO 8601 (API.md §1).
  static String? _formatDate(DateTime? value) {
    if (value == null) return null;
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  /// Applies the filters the API cannot express to a page of results — after
  /// dropping whatever has already left.
  List<Ride> refine(List<Ride> rides) {
    final upcoming = rides.upcomingOnly;
    if (!hasRefinements) return upcoming;
    return upcoming.where(_matches).toList(growable: false);
  }

  bool _matches(Ride ride) {
    if (maxPrice != null && ride.pricePerSeat > maxPrice!) return false;
    if (bands.isNotEmpty && !bands.any((b) => b.contains(ride.departureAt))) {
      return false;
    }
    return true;
  }

  RideSearchQuery copyWith({
    int? Function()? fromCityId,
    int? Function()? toCityId,
    DateTime? Function()? date,
    int? seats,
    RideSortOption? sort,
    double? Function()? maxPrice,
    Set<TimeOfDayBand>? bands,
    Gender? Function()? driverGender,
    bool? womenOnly,
    bool? instantOnly,
    bool? verifiedOnly,
  }) {
    return RideSearchQuery(
      fromCityId: fromCityId != null ? fromCityId() : this.fromCityId,
      toCityId: toCityId != null ? toCityId() : this.toCityId,
      date: date != null ? date() : this.date,
      seats: seats ?? this.seats,
      sort: sort ?? this.sort,
      maxPrice: maxPrice != null ? maxPrice() : this.maxPrice,
      bands: bands ?? this.bands,
      driverGender: driverGender != null ? driverGender() : this.driverGender,
      womenOnly: womenOnly ?? this.womenOnly,
      instantOnly: instantOnly ?? this.instantOnly,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
    );
  }

  RideSearchQuery swapped() =>
      copyWith(fromCityId: () => toCityId, toCityId: () => fromCityId);

  /// Clears only the filter sheet's fields, keeping route, date and seats.
  RideSearchQuery clearedFilters() => RideSearchQuery(
    fromCityId: fromCityId,
    toCityId: toCityId,
    date: date,
    seats: seats,
  );

  /// Whether a change needs a new request, or only re-running [refine] over
  /// what is already loaded.
  ///
  /// The server-side filters all belong here: unlike price and time band, they
  /// cannot be applied to a page already in hand — a ride the query excluded
  /// was never downloaded in the first place.
  bool needsRefetchFrom(RideSearchQuery previous) =>
      fromCityId != previous.fromCityId ||
      toCityId != previous.toCityId ||
      date != previous.date ||
      seats != previous.seats ||
      sort != previous.sort ||
      driverGender != previous.driverGender ||
      womenOnly != previous.womenOnly ||
      instantOnly != previous.instantOnly ||
      verifiedOnly != previous.verifiedOnly;

  @override
  List<Object?> get props => [
    fromCityId,
    toCityId,
    date,
    seats,
    sort,
    maxPrice,
    bands,
    driverGender,
    womenOnly,
    instantOnly,
    verifiedOnly,
  ];
}
