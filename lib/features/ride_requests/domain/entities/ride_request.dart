import 'package:equatable/equatable.dart';

import '../../../cities/domain/entities/city.dart';
import '../../../profile/domain/entities/app_user.dart';

/// Wire: `open | fulfilled | cancelled | expired` (API.md §19).
enum RideRequestStatus {
  /// Visible to drivers, and still being matched against new listings.
  open,

  /// The passenger booked a ride on this route — closed automatically.
  fulfilled,

  /// The passenger closed it themselves.
  cancelled,

  /// The date went past. The server's nightly `demand:tidy` closes these.
  expired;

  String get apiValue => name;

  bool get isOpen => this == RideRequestStatus.open;

  /// Whether the row still belongs in the passenger's "waiting" list.
  bool get isLive => this == RideRequestStatus.open;

  static RideRequestStatus fromApi(String? value) =>
      RideRequestStatus.values.firstWhere(
        (s) => s.apiValue == value,
        orElse: () => RideRequestStatus.open,
      );
}

/// A passenger saying "I want a seat on this route, on this date".
///
/// This is the half of the marketplace that did not exist before. Until now
/// only a driver could put something into it, so a passenger who searched and
/// found nothing had nothing to do but leave. A request turns that dead end
/// into two useful things at once: a concrete demand a driver can answer, and
/// an address to notify the moment a matching ride appears.
class RideRequest extends Equatable {
  const RideRequest({
    required this.id,
    required this.fromCity,
    required this.toCity,
    required this.wantedDate,
    required this.createdAt,
    this.passenger,
    this.flexibleDays = 0,
    this.seats = 1,
    this.note = '',
    this.status = RideRequestStatus.open,
    this.isMine = false,
    this.matchedRideId,
  });

  final int id;

  /// Absent on the passenger's own list, where it would only be themselves.
  final PublicUser? passenger;

  final City fromCity;
  final City toCity;

  /// Date only — no time. Asking a passenger for an exact hour before any ride
  /// exists would be asking them to guess.
  final DateTime wantedDate;

  /// 0–3. How many days either side of [wantedDate] still count as a match.
  ///
  /// Widening the window is what makes matching work at all: for someone going
  /// to their home district, Friday and Saturday are usually interchangeable,
  /// and demanding an exact date collapses the number of matches.
  final int flexibleDays;

  final int seats;
  final String note;
  final RideRequestStatus status;
  final bool isMine;

  /// The last ride the server matched to this request — where the "a ride
  /// appeared" notification points.
  final int? matchedRideId;

  final DateTime createdAt;

  /// The inclusive date window this request accepts.
  (DateTime, DateTime) get dateRange => (
    wantedDate.subtract(Duration(days: flexibleDays)),
    wantedDate.add(Duration(days: flexibleDays)),
  );

  bool get isFlexible => flexibleDays > 0;

  /// Whether the date has gone by. Checked on the client too, because a list
  /// left open overnight would otherwise still offer yesterday.
  bool get hasExpired {
    final now = DateTime.now();
    final lastDay = wantedDate.add(Duration(days: flexibleDays));
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).isAfter(DateTime(lastDay.year, lastDay.month, lastDay.day));
  }

  bool get canBeCancelled => isMine && status.isOpen && !hasExpired;

  RideRequest copyWith({RideRequestStatus? status, int? Function()? matchedRideId}) {
    return RideRequest(
      id: id,
      passenger: passenger,
      fromCity: fromCity,
      toCity: toCity,
      wantedDate: wantedDate,
      flexibleDays: flexibleDays,
      seats: seats,
      note: note,
      status: status ?? this.status,
      isMine: isMine,
      matchedRideId: matchedRideId != null ? matchedRideId() : this.matchedRideId,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    passenger,
    fromCity,
    toCity,
    wantedDate,
    flexibleDays,
    seats,
    note,
    status,
    isMine,
    matchedRideId,
    createdAt,
  ];
}

/// What the "tell drivers what you need" sheet collects.
///
/// A separate type from [RideRequest] for the same reason [RideDraft] is
/// separate from [Ride]: the form has no id, no status and no author, and its
/// validity is a question the form asks before the server ever sees it.
class RideRequestDraft extends Equatable {
  const RideRequestDraft({
    this.fromCityId,
    this.toCityId,
    this.wantedDate,
    this.flexibleDays = 1,
    this.seats = 1,
    this.note = '',
  });

  final int? fromCityId;
  final int? toCityId;
  final DateTime? wantedDate;

  /// Defaults to one day either side rather than zero: most passengers are a
  /// little flexible, and a request that matches nothing helps nobody.
  final int flexibleDays;

  final int seats;
  final String note;

  bool get isRouteValid =>
      fromCityId != null && toCityId != null && fromCityId != toCityId;

  bool get isComplete => isRouteValid && wantedDate != null;

  RideRequestDraft copyWith({
    int? Function()? fromCityId,
    int? Function()? toCityId,
    DateTime? Function()? wantedDate,
    int? flexibleDays,
    int? seats,
    String? note,
  }) {
    return RideRequestDraft(
      fromCityId: fromCityId != null ? fromCityId() : this.fromCityId,
      toCityId: toCityId != null ? toCityId() : this.toCityId,
      wantedDate: wantedDate != null ? wantedDate() : this.wantedDate,
      flexibleDays: flexibleDays ?? this.flexibleDays,
      seats: seats ?? this.seats,
      note: note ?? this.note,
    );
  }

  @override
  List<Object?> get props => [
    fromCityId,
    toCityId,
    wantedDate,
    flexibleDays,
    seats,
    note,
  ];
}
