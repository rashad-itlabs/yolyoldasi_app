part of 'write_review_bloc.dart';

class WriteReviewState extends Equatable {
  const WriteReviewState({
    this.status = DataStatus.initial,
    this.bookingId,
    this.booking,
    this.draft = const ReviewDraft(),
    this.submitStatus = ActionStatus.idle,
    this.savedReview,
    this.failure,
  });

  final DataStatus status;
  final int? bookingId;
  final Booking? booking;
  final ReviewDraft draft;
  final ActionStatus submitStatus;
  final Review? savedReview;
  final Failure? failure;

  /// Who is being reviewed, from the signed-in user's side of the booking.
  PublicUser? get target => booking?.counterpart;

  /// API.md §12: only a `completed` booking can be reviewed, and only once.
  bool get isReviewable => booking?.isReviewable ?? false;
  bool get alreadyReviewed =>
      booking != null && isReviewable && !booking!.needsMyReview;

  bool get isCommentTooLong => draft.comment.length > AppRules.maxReviewLength;

  bool get canSubmit =>
      draft.isValid &&
      !isCommentTooLong &&
      isReviewable &&
      !alreadyReviewed &&
      !submitStatus.isBusy;

  int get remainingCharacters =>
      AppRules.maxReviewLength - draft.comment.length;

  bool get isDuplicate => failure is ConflictFailure;

  WriteReviewState copyWith({
    DataStatus? status,
    int? bookingId,
    Booking? Function()? booking,
    ReviewDraft? draft,
    ActionStatus? submitStatus,
    Review? Function()? savedReview,
    Failure? Function()? failure,
  }) {
    return WriteReviewState(
      status: status ?? this.status,
      bookingId: bookingId ?? this.bookingId,
      booking: booking != null ? booking() : this.booking,
      draft: draft ?? this.draft,
      submitStatus: submitStatus ?? this.submitStatus,
      savedReview: savedReview != null ? savedReview() : this.savedReview,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [
    status,
    bookingId,
    booking,
    draft,
    submitStatus,
    savedReview,
    failure,
  ];
}
