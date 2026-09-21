import '../../../../core/error/result.dart';
import '../../../../core/network/api_envelope.dart';
import '../../../rides/domain/entities/ride.dart';
import '../entities/ride_request.dart';

/// A request plus whatever already matches it.
///
/// The two travel together because the API returns them together, and it does
/// that for a reason: a passenger who has just described what they need should
/// not be left on a "we'll let you know" screen if a ride is sitting there
/// right now.
typedef RideRequestWithMatches = ({RideRequest request, List<Ride> matches});

/// Passenger demand — API.md §19.
abstract interface class RideRequestRepository {
  /// `GET /ride-requests` — the passenger's own, open and fulfilled by default.
  FutureResult<Paginated<RideRequest>> mine({
    RideRequestStatus? status,
    int? page,
  });

  /// `POST /ride-requests`. Re-posting the same route and date updates the
  /// existing row rather than failing, so the form never has to handle a
  /// duplicate error.
  FutureResult<RideRequestWithMatches> create(RideRequestDraft draft);

  FutureResult<RideRequestWithMatches> byId(int requestId);

  /// `DELETE /ride-requests/{id}` — closes it; the row stays.
  FutureResult<RideRequest> cancel(int requestId);

  /// `GET /ride-requests/incoming` — what passengers want on the routes this
  /// driver runs. Without a route the server picks them from the driver's own
  /// past listings, falling back to their home city.
  FutureResult<Paginated<RideRequest>> incoming({
    int? fromCityId,
    int? toCityId,
    int? page,
  });
}
