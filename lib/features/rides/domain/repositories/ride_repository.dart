import '../../../../core/error/result.dart';
import '../../../../core/network/api_envelope.dart';
import '../entities/ride.dart';
import '../entities/ride_draft.dart';
import '../entities/ride_query.dart';

/// Publishing, editing and searching trips — API.md §9.
abstract interface class RideRepository {
  /// Fires after every write that succeeded — publish, edit, repeat, status
  /// change, cancel, complete.
  ///
  /// The driver's list and the passenger home are loaded once and outlive the
  /// screens that write, so without this a ride published from the form did
  /// not appear on the home tab until something else happened to reload it.
  Stream<void> get changes;

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

  /// `POST /rides/{id}/repeat` — the same run on a new date.
  ///
  /// The weekly commuter is the driver worth keeping, and making them refill
  /// the three-step form every Friday is how they get lost. [weeks] publishes
  /// several at once; the result is the first of them.
  FutureResult<Ride> repeat(int rideId, DateTime departureAt, {int weeks});

  /// Shows or hides a ride in search without cancelling its bookings.
  FutureResult<Ride> setStatus(int rideId, RideStatus status);

  /// `DELETE /rides/{id}` — cancels the ride and, with it, every pending and
  /// confirmed booking.
  FutureResult<void> cancel(int rideId);

  /// `POST /rides/{id}/complete` — closes the ride, completes its confirmed
  /// bookings and asks both sides for a review.
  FutureResult<void> complete(int rideId);
}
