import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_routes.dart';
import '../domain/entities/ride.dart';
import '../domain/entities/ride_query.dart';
import 'bloc/ride_search/ride_search_bloc.dart';

/// Opens the results screen on a fresh search for [ride]'s route and day.
///
/// The search query lives above the router (see `app.dart`), so this works from
/// anywhere — it is how a passenger who has lost a seat gets straight to the
/// alternatives rather than retyping the route they already chose.
///
/// Sorted by price on purpose: the caller is someone who either cancelled to
/// find something cheaper, or was left without a ride and is now comparing.
void searchSameRoute(BuildContext context, Ride ride, {int seats = 1}) {
  context.read<RideSearchBloc>().add(
    RideSearchQueryReplaced(
      RideSearchQuery(
        fromCityId: ride.fromCity.id,
        toCityId: ride.toCity.id,
        date: ride.departureAt,
        seats: seats.clamp(AppRules.minSeatsPerRide, AppRules.maxSeatsPerRide),
        sort: RideSortOption.cheapest,
      ),
      submit: true,
    ),
  );
  context.push(Routes.searchResults);
}
