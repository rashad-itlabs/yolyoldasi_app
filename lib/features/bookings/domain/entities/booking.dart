import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../profile/domain/entities/app_user.dart';
import '../../../rides/domain/entities/ride.dart';

/// Wire: `pending | confirmed | rejected | cancelled_by_passenger |
/// cancelled_by_driver | completed` (API.md §2).
enum BookingStatus {
  /// Waiting for the driver. Seats are already held.
  pending('pending'),

  /// The driver accepted — phone numbers unlock here.
  confirmed('confirmed'),

  /// The driver declined; the conversation is locked.
  rejected('rejected'),

  cancelledByPassenger('cancelled_by_passenger'),
  cancelledByDriver('cancelled_by_driver'),

  /// The trip took place, via `POST /rides/{id}/complete`.
  completed('completed');

  const BookingStatus(this.apiValue);

  final String apiValue;

  bool get holdsSeats =>
      this == BookingStatus.pending || this == BookingStatus.confirmed;

  bool get isCancelled =>
      this == BookingStatus.cancelledByPassenger ||
      this == BookingStatus.cancelledByDriver;

  bool get isActive =>
      this == BookingStatus.pending || this == BookingStatus.confirmed;

  /// `contact_phone` is only present in these two states (API.md §10).
  bool get unlocksContact =>
      this == BookingStatus.confirmed || this == BookingStatus.completed;

  /// The conversation is locked once the booking is rejected or cancelled.
  bool get locksConversation => this == BookingStatus.rejected || isCancelled;

  static BookingStatus fromApi(String? value) =>
      BookingStatus.values.firstWhere(
        (s) => s.apiValue == value,
        orElse: () => BookingStatus.pending,
      );
}

/// The actions API.md §10 offers on an existing booking.
///
/// Carried as a value so a screen can phrase its confirmation: `block` and
/// `unblock` leave `status` untouched, so the booking that comes back cannot on
/// its own say what just happened to it.
enum BookingAction { confirm, reject, cancel, block, unblock }

/// The preset answers behind `reason` on `POST /bookings/{id}/cancel`.
///
/// The endpoint stores free text (≤255, API.md §10) and has no enum of its own,
/// so what goes on the wire is the label in the canceller's language — the most
/// the field can carry. The presets differ per side because "the driver is not
/// responding" is not something a driver cancels over.
enum BookingCancelReason {
  /// Either side: the trip is simply not happening for them any more.
  planChanged,

  /// Passenger only — the reason this flow exists for most often.
  foundCheaper,

  /// Passenger only.
  noAnswer,

  /// Driver only.
  vehicleProblem,

  /// Driver only.
  rescheduled,

  /// Free text instead of a preset.
  other;

  static const List<BookingCancelReason> _passenger = [
    planChanged,
    foundCheaper,
    noAnswer,
    other,
  ];

  static const List<BookingCancelReason> _driver = [
    planChanged,
    vehicleProblem,
    rescheduled,
    other,
  ];

  static List<BookingCancelReason> presetsFor({required bool asDriver}) =>
      asDriver ? _driver : _passenger;

  /// [other] carries whatever the user typed rather than its own label.
  bool get isFreeText => this == BookingCancelReason.other;
}

/// A passenger's claim on one or more seats — the booking object in API.md §10.
class Booking extends Equatable {
  const Booking({
    required this.id,
    required this.ride,
    required this.seats,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    this.passenger,
    this.driver,
    this.message = '',
    this.decidedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.passengerReviewed = false,
    this.driverReviewed = false,
    this.conversationId,
    this.contactPhone,
    this.passengerBlocked = false,
  });

  final int id;

  /// The full ride object, embedded by the API.
  final Ride ride;

  /// Both sides of the booking. Nullable because a deleted account leaves the
  /// block out (API.md §1 treats deleted users as 404s).
  final PublicUser? passenger;
  final PublicUser? driver;

  final int seats;
  final double totalPrice;
  final BookingStatus status;

  final DateTime createdAt;

  /// When the driver accepted or declined.
  final DateTime? decidedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;

  /// The note the passenger attached to the request.
  final String message;

  /// Whether each side has already left their review for this trip.
  final bool passengerReviewed;
  final bool driverReviewed;

  /// The thread opened alongside the booking — the two sides can write before
  /// the driver has decided (API.md §10).
  final int? conversationId;

  /// The other party's number. Absent unless [status] unlocks it.
  final String? contactPhone;

  /// The driver shut this ride to this passenger after they cancelled.
  ///
  /// A passenger's own cancellation normally reopens the ride (API.md §10).
  /// This is the driver's veto over that — the one case where a re-booking is
  /// refused, decided by the person whose seat it is rather than by a blanket
  /// rule.
  final bool passengerBlocked;

  /// True when the signed-in user is the driver on this booking, which the
  /// embedded ride already knows.
  bool get isMineAsDriver => ride.isMine;

  /// The other party, from the signed-in user's point of view.
  PublicUser? get counterpart => isMineAsDriver ? passenger : driver;

  bool get isUpcoming =>
      status.isActive && ride.departureAt.isAfter(DateTime.now());

  bool get hasContact => contactPhone != null && contactPhone!.isNotEmpty;

  /// Either side may cancel while the trip has not departed.
  bool get canCancel =>
      status.isActive && ride.departureAt.isAfter(DateTime.now());

  /// Cancelling this close to departure leaves the other side stranded, so the
  /// UI warns before going ahead.
  bool get isLateCancellation =>
      ride.departureAt.difference(DateTime.now()) <
      AppRules.freeCancellationWindow;

  /// The passenger has no seat on a ride that has not left yet — whichever
  /// side ended it.
  bool get _passengerIsOut =>
      !isMineAsDriver &&
      !status.isActive &&
      status != BookingStatus.completed &&
      ride.departureAt.isAfter(DateTime.now());

  /// The driver is the one who shut this ride to them: declined, cancelled it
  /// themselves, or blocked them after a cancellation.
  ///
  /// All three are the same answer from the same person, so the screens say so
  /// in the same words.
  bool get isClosedByDriver =>
      status == BookingStatus.rejected ||
      status == BookingStatus.cancelledByDriver ||
      passengerBlocked;

  /// The passenger walked away from their own booking, and the ride will take
  /// them back.
  ///
  /// Whoever said "no" decides whether the door reopens (API.md §10): a
  /// passenger's own cancellation is not final, so a change of heart — or a
  /// cheaper ride that fell through — can be undone, unless the driver has
  /// since used their veto.
  ///
  /// The embedded ride is a snapshot from when the booking was read, so this
  /// only decides whether to *offer* the way back. The seat count is settled by
  /// re-reading the ride, and the 409 is still the last word.
  bool get canRebookSameRide =>
      _passengerIsOut &&
      status == BookingStatus.cancelledByPassenger &&
      !passengerBlocked &&
      ride.isBookable;

  /// Off the ride with no way back onto it — the driver closed it to them, or
  /// the seat went while they were away. Either way the route is the only
  /// thing left to offer, which is what the UI does instead of a dead end.
  bool get needsAnotherRide => _passengerIsOut && !canRebookSameRide;

  /// `POST /bookings/{id}/block` — the driver's answer to a cancellation.
  ///
  /// Only worth offering while the ride could still be re-booked; once it has
  /// left, blocking changes nothing.
  bool get canBlockPassenger =>
      isMineAsDriver &&
      status == BookingStatus.cancelledByPassenger &&
      !passengerBlocked &&
      ride.departureAt.isAfter(DateTime.now());

  /// Drivers block in the heat of the moment, so the way back is always open.
  bool get canUnblockPassenger =>
      isMineAsDriver &&
      passengerBlocked &&
      ride.departureAt.isAfter(DateTime.now());

  /// `POST /bookings/{id}/confirm` and `/reject` are driver-only and only make
  /// sense while the request is pending.
  bool get canDriverDecide => isMineAsDriver && status == BookingStatus.pending;

  /// Reviews may only be written on a completed booking, and stay open for a
  /// fortnight after the trip.
  bool get isReviewable =>
      status == BookingStatus.completed &&
      DateTime.now().difference(ride.departureAt) < AppRules.reviewWindow;

  /// Whether the signed-in user still owes a review. The API decides who the
  /// author is, so the side is read off the ride's `is_mine`.
  bool get needsMyReview =>
      isReviewable && !(isMineAsDriver ? driverReviewed : passengerReviewed);

  bool hasReviewedBy({required bool asDriver}) =>
      asDriver ? driverReviewed : passengerReviewed;

  Booking copyWith({
    Ride? ride,
    PublicUser? Function()? passenger,
    PublicUser? Function()? driver,
    int? seats,
    double? totalPrice,
    BookingStatus? status,
    DateTime? Function()? decidedAt,
    DateTime? Function()? cancelledAt,
    String? Function()? cancellationReason,
    String? message,
    bool? passengerReviewed,
    bool? driverReviewed,
    int? Function()? conversationId,
    String? Function()? contactPhone,
    bool? passengerBlocked,
  }) {
    return Booking(
      id: id,
      ride: ride ?? this.ride,
      passenger: passenger != null ? passenger() : this.passenger,
      driver: driver != null ? driver() : this.driver,
      seats: seats ?? this.seats,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      createdAt: createdAt,
      decidedAt: decidedAt != null ? decidedAt() : this.decidedAt,
      cancelledAt: cancelledAt != null ? cancelledAt() : this.cancelledAt,
      cancellationReason: cancellationReason != null
          ? cancellationReason()
          : this.cancellationReason,
      message: message ?? this.message,
      passengerReviewed: passengerReviewed ?? this.passengerReviewed,
      driverReviewed: driverReviewed ?? this.driverReviewed,
      conversationId: conversationId != null
          ? conversationId()
          : this.conversationId,
      contactPhone: contactPhone != null ? contactPhone() : this.contactPhone,
      passengerBlocked: passengerBlocked ?? this.passengerBlocked,
    );
  }

  @override
  List<Object?> get props => [
    id,
    ride,
    passenger,
    driver,
    seats,
    totalPrice,
    status,
    createdAt,
    decidedAt,
    cancelledAt,
    cancellationReason,
    message,
    passengerReviewed,
    driverReviewed,
    conversationId,
    contactPhone,
    passengerBlocked,
  ];
}

/// What the request sheet collects for `POST /rides/{id}/bookings`.
class BookingRequest extends Equatable {
  const BookingRequest({required this.seats, this.message = ''});

  final int seats;
  final String message;

  bool get isValid =>
      seats >= AppRules.minSeatsPerRide &&
      seats <= AppRules.maxSeatsPerRide &&
      message.length <= AppRules.maxBookingMessageLength;

  BookingRequest copyWith({int? seats, String? message}) => BookingRequest(
    seats: seats ?? this.seats,
    message: message ?? this.message,
  );

  @override
  List<Object?> get props => [seats, message];
}
