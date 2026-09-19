part of 'report_bloc.dart';

sealed class ReportEvent extends Equatable {
  const ReportEvent();

  @override
  List<Object?> get props => const [];
}

/// Opens the sheet against one user, optionally with the ride or booking that
/// prompted it.
class ReportStarted extends ReportEvent {
  const ReportStarted({
    required this.targetUserId,
    this.rideId,
    this.bookingId,
  });

  final int targetUserId;
  final int? rideId;
  final int? bookingId;

  @override
  List<Object?> get props => [targetUserId, rideId, bookingId];
}

class ReportReasonSelected extends ReportEvent {
  const ReportReasonSelected(this.reason);

  final ReportReason reason;

  @override
  List<Object?> get props => [reason];
}

class ReportDetailsChanged extends ReportEvent {
  const ReportDetailsChanged(this.details);

  final String details;

  @override
  List<Object?> get props => [details];
}

class ReportSubmitted extends ReportEvent {
  const ReportSubmitted();
}

class ReportFailureCleared extends ReportEvent {
  const ReportFailureCleared();
}
