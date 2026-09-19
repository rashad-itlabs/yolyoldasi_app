part of 'write_review_bloc.dart';

sealed class WriteReviewEvent extends Equatable {
  const WriteReviewEvent();

  @override
  List<Object?> get props => const [];
}

class WriteReviewStarted extends WriteReviewEvent {
  const WriteReviewStarted(this.bookingId);

  final int bookingId;

  @override
  List<Object?> get props => [bookingId];
}

class WriteReviewRatingChanged extends WriteReviewEvent {
  const WriteReviewRatingChanged(this.rating);

  /// 1–5.
  final int rating;

  @override
  List<Object?> get props => [rating];
}

class WriteReviewCommentChanged extends WriteReviewEvent {
  const WriteReviewCommentChanged(this.comment);

  final String comment;

  @override
  List<Object?> get props => [comment];
}

class WriteReviewSubmitted extends WriteReviewEvent {
  const WriteReviewSubmitted();
}

class WriteReviewFailureCleared extends WriteReviewEvent {
  const WriteReviewFailureCleared();
}
