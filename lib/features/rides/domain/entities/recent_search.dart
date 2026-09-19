import 'package:equatable/equatable.dart';

import '../../../cities/domain/entities/city.dart';
import 'ride_query.dart';

/// A route the user searched before — `GET /me/recent-searches` (API.md §14).
///
/// The server records one row per route on every search, keeps the last ten and
/// hands them back newest first, so the client neither writes nor prunes them.
class RecentSearch extends Equatable {
  const RecentSearch({
    required this.fromCity,
    required this.toCity,
    required this.searchedAt,
    this.searchedDate,
    this.seats = 1,
  });

  final City fromCity;
  final City toCity;

  /// The `date` the search carried, if any. `YYYY-MM-DD` on the wire — the one
  /// field that is not ISO 8601.
  final DateTime? searchedDate;

  final int seats;
  final DateTime searchedAt;

  /// Whether the saved date is still in the future and worth re-using; a chip
  /// that would search a past date drops it instead.
  bool get hasUsableDate {
    final date = searchedDate;
    if (date == null) return false;
    final today = DateTime.now();
    return !date.isBefore(DateTime(today.year, today.month, today.day));
  }

  /// Rebuilds the query this row came from, so tapping the chip repeats it.
  RideSearchQuery toQuery() => RideSearchQuery(
    fromCityId: fromCity.id,
    toCityId: toCity.id,
    date: hasUsableDate ? searchedDate : null,
    seats: seats,
  );

  @override
  List<Object?> get props => [fromCity, toCity, searchedDate, seats];
}
