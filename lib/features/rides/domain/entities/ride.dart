import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../cities/domain/entities/city.dart';
import '../../../profile/domain/entities/app_user.dart';
import '../../../profile/domain/entities/vehicle.dart';

/// Wire: `active | inactive | completed | cancelled` (API.md §2).
enum RideStatus {
  /// Visible in search and accepting bookings.
  active,

  /// Hidden from search by the driver; existing bookings stand.
  inactive,

  /// The driver closed it with `POST /rides/{id}/complete`.
  completed,

  /// Called off; every pending and confirmed booking was cancelled with it.
  cancelled;

  String get apiValue => name;

  bool get isActive => this == RideStatus.active;
  bool get isFinished =>
      this == RideStatus.completed || this == RideStatus.cancelled;

  /// Only an `active` ride can be edited (API.md §9).
  bool get isEditable => isActive;

  static RideStatus fromApi(String? value) => RideStatus.values.firstWhere(
    (s) => s.apiValue == value,
    orElse: () => RideStatus.active,
  );
}

/// A published trip with seats for sale — the ride object in API.md §9.
class Ride extends Equatable {
  const Ride({
    required this.id,
    required this.driver,
    required this.fromCity,
    required this.toCity,
    required this.departureAt,
    required this.totalSeats,
    required this.bookedSeats,
    required this.seatsLeft,
    required this.pricePerSeat,
    required this.status,
    required this.createdAt,
    this.vehicle,
    this.note = '',
    this.pickupPoint = '',
    this.dropoffPoint = '',
    this.instantBooking = false,
    this.isMine = false,
  });

  final int id;

  final PublicUser driver;

  /// `null` only if the API omitted the block; every real ride has a car.
  final Vehicle? vehicle;

  final City fromCity;
  final City toCity;

  final DateTime departureAt;

  /// Seats originally offered (1–4).
  final int totalSeats;

  /// Seats held by pending *and* confirmed bookings.
  final int bookedSeats;

  /// API.md §16.3 is explicit: use the server's number, do not recompute it
  /// from [totalSeats] and [bookedSeats], which can be stale on the client.
  final int seatsLeft;

  final double pricePerSeat;
  final RideStatus status;
  final DateTime createdAt;

  final String note;
  final String pickupPoint;
  final String dropoffPoint;

  /// When `true`, bookings skip the driver's approval and are confirmed on the
  /// spot (API.md §10).
  final bool instantBooking;

  /// Whether the signed-in user is the driver. Comes from the server, so the
  /// UI never has to compare ids itself.
  final bool isMine;

  bool get isFull => seatsLeft <= 0;

  /// Rough drive time between the two city centres, or `null` when either city
  /// is missing from the local coordinate table.
  Duration? get estimatedDuration => City.estimatedDrive(fromCity, toCity);

  double? get distanceKm => City.distanceKm(fromCity, toCity);

  DateTime? get estimatedArrival {
    final duration = estimatedDuration;
    return duration == null ? null : departureAt.add(duration);
  }

  bool get hasDeparted => DateTime.now().isAfter(departureAt);

  /// Bookings close shortly before departure. The API enforces this with a 422;
  /// the button is disabled first so the passenger is not sent into a dead end.
  bool get isPastBookingCutoff =>
      DateTime.now().isAfter(departureAt.subtract(AppRules.bookingCutoff));

  /// The single check the booking flow gates on. `isMine` is part of it because
  /// booking your own ride is a 422 (API.md §10).
  bool get isBookable =>
      status.isActive && !isMine && !isFull && !isPastBookingCutoff;

  /// Whether [seatCount] seats can still be taken.
  bool canFit(int seatCount) => isBookable && seatsLeft >= seatCount;

  double totalPriceFor(int seatCount) => pricePerSeat * seatCount;

  /// `POST /rides/{id}/complete` is refused while departure is in the future.
  bool get canBeCompleted => isMine && status.isActive && hasDeparted;

  /// The plate, which the API returns only to the driver (API.md §9).
  String? get visiblePlate => vehicle?.plate;

  Ride copyWith({
    PublicUser? driver,
    Vehicle? Function()? vehicle,
    City? fromCity,
    City? toCity,
    DateTime? departureAt,
    int? totalSeats,
    int? bookedSeats,
    int? seatsLeft,
    double? pricePerSeat,
    RideStatus? status,
    String? note,
    String? pickupPoint,
    String? dropoffPoint,
    bool? instantBooking,
    bool? isMine,
  }) {
    return Ride(
      id: id,
      driver: driver ?? this.driver,
      vehicle: vehicle != null ? vehicle() : this.vehicle,
      fromCity: fromCity ?? this.fromCity,
      toCity: toCity ?? this.toCity,
      departureAt: departureAt ?? this.departureAt,
      totalSeats: totalSeats ?? this.totalSeats,
      bookedSeats: bookedSeats ?? this.bookedSeats,
      seatsLeft: seatsLeft ?? this.seatsLeft,
      pricePerSeat: pricePerSeat ?? this.pricePerSeat,
      status: status ?? this.status,
      createdAt: createdAt,
      note: note ?? this.note,
      pickupPoint: pickupPoint ?? this.pickupPoint,
      dropoffPoint: dropoffPoint ?? this.dropoffPoint,
      instantBooking: instantBooking ?? this.instantBooking,
      isMine: isMine ?? this.isMine,
    );
  }

  @override
  List<Object?> get props => [
    id,
    driver,
    vehicle,
    fromCity,
    toCity,
    departureAt,
    totalSeats,
    bookedSeats,
    seatsLeft,
    pricePerSeat,
    status,
    createdAt,
    note,
    pickupPoint,
    dropoffPoint,
    instantBooking,
    isMine,
  ];
}

extension UpcomingRides on List<Ride> {
  /// Drops the rides that have already left.
  ///
  /// Every list a passenger looks at goes through this, because "expired" is
  /// not something the client can leave to the server: a list loaded at 09:58
  /// is still on screen at 10:01, and the 10:00 departure in it has to go.
  List<Ride> get upcomingOnly =>
      where((ride) => !ride.hasDeparted).toList(growable: false);
}
