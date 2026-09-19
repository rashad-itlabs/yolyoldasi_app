part of 'report_bloc.dart';

class ReportState extends Equatable {
  const ReportState({
    this.draft,
    this.status = ActionStatus.idle,
    this.failure,
  });

  /// `null` until the sheet opens against a specific user.
  final ReportDraft? draft;

  final ActionStatus status;
  final Failure? failure;

  ReportReason? get reason => draft?.reason;
  String get details => draft?.details ?? '';

  /// `details` becomes required once "other" is picked (API.md §15).
  bool get needsDetails => reason?.requiresDetails ?? false;

  bool get isDetailsTooLong => details.length > AppRules.maxReportDetailsLength;

  bool get canSubmit => (draft?.isValid ?? false) && !status.isBusy;

  int get remainingCharacters =>
      AppRules.maxReportDetailsLength - details.length;

  ReportState copyWith({
    ReportDraft? draft,
    ActionStatus? status,
    Failure? Function()? failure,
  }) {
    return ReportState(
      draft: draft ?? this.draft,
      status: status ?? this.status,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [draft, status, failure];
}
