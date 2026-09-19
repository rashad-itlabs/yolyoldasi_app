import '../../../../core/error/result.dart';
import '../../../../core/network/api_envelope.dart';
import '../entities/recent_search.dart';
import '../entities/ride.dart';
import '../entities/ride_draft.dart';
import '../entities/ride_query.dart';

/// Publishing, editing and searching trips — API.md §9.
abstract interface class RideRepository {
  /// `GET /rides`. Only `active`, future-dated rides with enough free seats
  /// come back, 20 to a page.
  FutureResult<Paginated<Ride>> search(RideSearchQuery query, {int? page});

  /// `GET /rides/mine` — the signed-in driver's listings.
  FutureResult<Paginated<Ride>> mine({RideStatus? status, int? page});

  FutureResult<Ride> byId(int rideId);

  /// `POST /rides`.
  FutureResult<Ride> publish(RideDraft draft);

  /// `PUT /rides/{id}`.
  FutureResult<Ride> update(int rideId, RideDraft draft);

  /// Shows or hides a ride in search without cancelling its bookings.
  FutureResult<Ride> setStatus(int rideId, RideStatus status);

  /// `DELETE /rides/{id}` — cancels the ride and, with it, every pending and
  /// confirmed booking.
  FutureResult<void> cancel(int rideId);

  /// `POST /rides/{id}/complete` — closes the ride, completes its confirmed
  /// bookings and asks both sides for a review.
  FutureResult<void> complete(int rideId);

  /// `GET /me/recent-searches` — the last ten routes, newest first.
  FutureResult<List<RecentSearch>> recentSearches();

  FutureResult<void> clearRecentSearches();
}
