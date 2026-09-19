part of 'booking_detail_bloc.dart';

class BookingDetailState extends Equatable {
  const BookingDetailState({
    this.status = DataStatus.initial,
    this.bookingId,
    this.booking,
    this.actionStatus = ActionStatus.idle,
    this.lastAction,
    this.failure,
  });

  final DataStatus status;
  final int? bookingId;
  final Booking? booking;
  final ActionStatus actionStatus;

  /// What [actionStatus] refers to. Block and unblock leave `status` alone, so
  /// the booking cannot say on its own what just succeeded.
  final BookingAction? lastAction;

  final Failure? failure;

  bool get isDriver => booking?.isMineAsDriver ?? false;
  bool get canDecide => booking?.canDriverDecide ?? false;
  bool get canCancel => booking?.canCancel ?? false;
  bool get needsReview => booking?.needsMyReview ?? false;
  bool get canBlockPassenger => booking?.canBlockPassenger ?? false;
  bool get canUnblockPassenger => booking?.canUnblockPassenger ?? false;

  /// The counterpart's number, which the API only sends once the booking is
  /// confirmed or completed (API.md §10).
  String? get contactPhone => booking?.contactPhone;
  bool get hasContact => booking?.hasContact ?? false;

  /// The thread is reachable from the moment the booking exists, but the
  /// composer is disabled once it locks.
  int? get conversationId => booking?.conversationId;
  bool get isConversationLocked => booking?.status.locksConversation ?? false;

  BookingDetailState copyWith({
    DataStatus? status,
    int? bookingId,
    Booking? Function()? booking,
    ActionStatus? actionStatus,
    BookingAction? Function()? lastAction,
    Failure? Function()? failure,
  }) {
    return BookingDetailState(
      status: status ?? this.status,
      bookingId: bookingId ?? this.bookingId,
      booking: booking != null ? booking() : this.booking,
      actionStatus: actionStatus ?? this.actionStatus,
      lastAction: lastAction != null ? lastAction() : this.lastAction,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [
    status,
    bookingId,
    booking,
    actionStatus,
    lastAction,
    failure,
  ];
}
