part of 'publish_ride_bloc.dart';

sealed class PublishRideEvent extends Equatable {
  const PublishRideEvent();

  @override
  List<Object?> get props => const [];
}

/// Opens the form. With [rideId] it loads that ride and switches to edit mode;
/// without, it starts a blank draft seeded from the driver's defaults.
class PublishRideStarted extends PublishRideEvent {
  const PublishRideStarted({
    this.rideId,
    this.vehicleId,
    this.instantBookingDefault = false,
    this.prefill,
  });

  final int? rideId;

  /// The driver's car, pre-selected so a one-car driver never sees a picker.
  final int? vehicleId;

  /// `instant_booking_default` from the driver profile (API.md §7).
  final bool instantBookingDefault;

  /// A route and date the form should open with.
  ///
  /// Set when the driver arrived from a passenger's request or from the demand
  /// list — they have already been shown the route, and asking them to type it
  /// back in is the surest way to lose them between the two screens.
  final RidePrefill? prefill;

  @override
  List<Object?> get props => [
    rideId,
    vehicleId,
    instantBookingDefault,
    prefill,
  ];
}

/// A route (and optionally a date) handed to the publish form on open.
class RidePrefill extends Equatable {
  const RidePrefill({required this.fromCityId, required this.toCityId, this.date});

  final int fromCityId;
  final int toCityId;
  final DateTime? date;

  @override
  List<Object?> get props => [fromCityId, toCityId, date];
}

class PublishRideFieldChanged extends PublishRideEvent {
  const PublishRideFieldChanged({
    this.vehicleId,
    this.fromCityId,
    this.toCityId,
    this.date,
    this.timeOfDayMinutes,
    this.totalSeats,
    this.pricePerSeat,
    this.note,
    this.pickupPoint,
    this.dropoffPoint,
    this.instantBooking,
    this.womenOnly,
    this.repeatWeeks,
  });

  final int? vehicleId;
  final int? fromCityId;
  final int? toCityId;
  final DateTime? date;
  final int? timeOfDayMinutes;
  final int? totalSeats;
  final double? pricePerSeat;
  final String? note;
  final String? pickupPoint;
  final String? dropoffPoint;
  final bool? instantBooking;
  final bool? womenOnly;
  final int? repeatWeeks;

  @override
  List<Object?> get props => [
    vehicleId,
    fromCityId,
    toCityId,
    date,
    timeOfDayMinutes,
    totalSeats,
    pricePerSeat,
    note,
    pickupPoint,
    dropoffPoint,
    instantBooking,
    womenOnly,
    repeatWeeks,
  ];
}

class PublishRideRouteSwapped extends PublishRideEvent {
  const PublishRideRouteSwapped();
}

/// Moves between the form's steps. Kept in the bloc so the progress indicator
/// and the "back" behaviour have a single source.
class PublishRideStepChanged extends PublishRideEvent {
  const PublishRideStepChanged(this.step);

  final PublishStep step;

  @override
  List<Object?> get props => [step];
}

/// `POST /rides`, or `PUT /rides/{id}` when editing.
class PublishRideSubmitted extends PublishRideEvent {
  const PublishRideSubmitted();
}

class PublishRideFailureCleared extends PublishRideEvent {
  const PublishRideFailureCleared();
}
