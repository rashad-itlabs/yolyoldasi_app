import 'package:equatable/equatable.dart';

import '../../../../core/constants/az_cities.dart';

/// A city as the API defines it: `{ "id": 1, "name": "Bakı" }` (API.md §6).
///
/// The API is the authority on the id and on which cities exist. Everything
/// else the UI needs — the Russian and English spellings, the coordinates
/// behind the price hint and the arrival estimate — comes from the local
/// [AzCities] table, matched by name.
class City extends Equatable {
  const City({required this.id, required this.name});

  final int id;

  /// The Azerbaijani name, exactly as the API returned it.
  final String name;

  AzCity? get _geo => AzCities.byName(name);

  /// The name to show in [languageCode], falling back to the API's spelling
  /// for a city the local table has never heard of.
  String nameFor(String languageCode) => _geo?.nameFor(languageCode) ?? name;

  /// Surfaced first in the picker and on the search home screen.
  bool get isPopular => _geo?.isPopular ?? false;

  double? get lat => _geo?.lat;
  double? get lng => _geo?.lng;

  /// Lowercased, diacritic-free haystack so "gence", "gəncə" and "Гянджа" all
  /// match the same row.
  String searchHaystack(String languageCode) =>
      _geo?.searchHaystack(languageCode) ?? AzCity.foldQuery(name);

  bool matches(String foldedQuery, String languageCode) =>
      foldedQuery.isEmpty || searchHaystack(languageCode).contains(foldedQuery);

  /// Straight-line distance in km, or `null` when either city is missing from
  /// the local coordinate table.
  static double? distanceKm(City? a, City? b) {
    final from = a?._geo;
    final to = b?._geo;
    if (from == null || to == null) return null;
    return AzCities.distanceKm(from, to);
  }

  /// Rough driving time between the two city centres.
  static Duration? estimatedDrive(City? a, City? b) {
    final from = a?._geo;
    final to = b?._geo;
    if (from == null || to == null) return null;
    return AzCities.estimatedDrive(from, to);
  }

  /// A price the driver is likely to charge, derived from distance. Shown as a
  /// hint on the publish form — never enforced, and `null` without coordinates.
  static double? suggestedPrice(City? from, City? to) {
    final km = distanceKm(from, to);
    if (km == null) return null;
    // ~0.09 AZN per km per seat over the road-adjusted distance, rounded to
    // the nearest 0.5 AZN.
    final raw = km * 1.25 * 0.09;
    return (raw * 2).round() / 2;
  }

  /// Sorts popular cities first, then alphabetically in [languageCode].
  static int compareForPicker(City a, City b, String languageCode) {
    if (a.isPopular != b.isPopular) return a.isPopular ? -1 : 1;
    return a.nameFor(languageCode).compareTo(b.nameFor(languageCode));
  }

  @override
  List<Object?> get props => [id, name];
}
