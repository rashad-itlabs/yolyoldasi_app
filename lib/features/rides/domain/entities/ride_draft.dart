import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../cities/domain/entities/city.dart';
import 'ride.dart';

/// What the driver fills in on the publish form.
///
/// Separate from [Ride] so the form never has to invent ids, a driver profile
/// or seat counters, and so its validity can be asked about per step.
class RideDraft extends Equatable {
  const RideDraft({
    this.vehicleId,
    this.fromCityId,
    this.toCityId,
    this.date,
    this.timeOfDayMinutes,
    this.totalSeats = 3,
    this.pricePerSeat,
    this.note = '',
    this.pickupPoint = '',
    this.dropoffPoint = '',
    this.instantBooking = false,
    this.womenOnly = false,
    this.repeatWeeks = 1,
  });

  final int? vehicleId;
  final int? fromCityId;
  final int? toCityId;
  final DateTime? date;

  /// Minutes since midnight — kept apart from [date] because the form collects
  /// them on different steps.
  final int? timeOfDayMinutes;

  final int totalSeats;
  final double? pricePerSeat;
  final String note;
  final String pickupPoint;
  final String dropoffPoint;
  final bool instantBooking;

  /// Only women may book. Offered on the form only to a driver whose own
  /// profile says `female` — the server refuses it otherwise (API.md §21).
  final bool womenOnly;

  /// How many consecutive weeks to publish this run for, 1–8.
  ///
  /// The weekly commuter is the driver worth keeping, and making them refill
  /// the three-step form every Friday is how you lose them. Not part of
  /// [RideDraft.fromRide]: editing one listing never fans out into eight.
  final int repeatWeeks;

  factory RideDraft.fromRide(Ride ride) => RideDraft(
    vehicleId: ride.vehicle?.id,
    fromCityId: ride.fromCity.id,
    toCityId: ride.toCity.id,
    date: DateTime(
      ride.departureAt.year,
      ride.departureAt.month,
      ride.departureAt.day,
    ),
    timeOfDayMinutes: ride.departureAt.hour * 60 + ride.departureAt.minute,
    totalSeats: ride.totalSeats,
    pricePerSeat: ride.pricePerSeat,
    note: ride.note,
    pickupPoint: ride.pickupPoint,
    dropoffPoint: ride.dropoffPoint,
    instantBooking: ride.instantBooking,
    womenOnly: ride.womenOnly,
  );

  DateTime? get departureAt {
    final day = date;
    final minutes = timeOfDayMinutes;
    if (day == null || minutes == null) return null;
    return DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
  }

  bool get isRouteValid =>
      fromCityId != null && toCityId != null && fromCityId != toCityId;

  bool get isScheduleValid {
    final at = departureAt;
    return at != null && at.isAfter(DateTime.now());
  }

  bool get isDetailsValid {
    final price = pricePerSeat;
    return price != null &&
        price >= AppRules.minPricePerSeat &&
        price <= AppRules.maxPricePerSeat &&
        totalSeats >= AppRules.minSeatsPerRide &&
        totalSeats <= AppRules.maxSeatsPerRide;
  }

  /// `POST /rides` requires a car, and it must be one of the driver's own.
  bool get isVehicleValid => vehicleId != null;

  bool get isComplete =>
      isVehicleValid && isRouteValid && isScheduleValid && isDetailsValid;

  /// The price hint on the details step, derived from the route's length.
  double? suggestedPrice(City? from, City? to) => City.suggestedPrice(from, to);

  RideDraft copyWith({
    int? Function()? vehicleId,
    int? Function()? fromCityId,
    int? Function()? toCityId,
    DateTime? Function()? date,
    int? Function()? timeOfDayMinutes,
    int? totalSeats,
    double? Function()? pricePerSeat,
    String? note,
    String? pickupPoint,
    String? dropoffPoint,
    bool? instantBooking,
    bool? womenOnly,
    int? repeatWeeks,
  }) {
    return RideDraft(
      vehicleId: vehicleId != null ? vehicleId() : this.vehicleId,
      fromCityId: fromCityId != null ? fromCityId() : this.fromCityId,
      toCityId: toCityId != null ? toCityId() : this.toCityId,
      date: date != null ? date() : this.date,
      timeOfDayMinutes: timeOfDayMinutes != null
          ? timeOfDayMinutes()
          : this.timeOfDayMinutes,
      totalSeats: totalSeats ?? this.totalSeats,
      pricePerSeat: pricePerSeat != null ? pricePerSeat() : this.pricePerSeat,
      note: note ?? this.note,
      pickupPoint: pickupPoint ?? this.pickupPoint,
      dropoffPoint: dropoffPoint ?? this.dropoffPoint,
      instantBooking: instantBooking ?? this.instantBooking,
      womenOnly: womenOnly ?? this.womenOnly,
      repeatWeeks: repeatWeeks ?? this.repeatWeeks,
    );
  }

  /// Swaps origin and destination — the arrow button between the two pickers.
  RideDraft swapped() =>
      copyWith(fromCityId: () => toCityId, toCityId: () => fromCityId);

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
