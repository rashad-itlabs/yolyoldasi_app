import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/data_status.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/result.dart';
import '../../../../bookings/domain/entities/booking.dart';
import '../../../../bookings/domain/repositories/booking_repository.dart';
import '../../../../profile/domain/entities/app_user.dart';
import '../../../domain/entities/review.dart';
import '../../../domain/repositories/review_repository.dart';

part 'write_review_event.dart';
part 'write_review_state.dart';

/// `POST /bookings/{id}/reviews` (API.md §12).
///
/// The booking is loaded first because the screen shows who is being reviewed,
/// and because only a `completed` booking can be reviewed at all — better to
/// find that out before the user has typed a paragraph.
class WriteReviewBloc extends Bloc<WriteReviewEvent, WriteReviewState> {
  WriteReviewBloc({
    required ReviewRepository reviews,
    required BookingRepository bookings,
  }) : _reviews = reviews,
       _bookings = bookings,
       super(const WriteReviewState()) {
    on<WriteReviewStarted>(_onStarted);
    on<WriteReviewRatingChanged>(_onRatingChanged);
    on<WriteReviewCommentChanged>(_onCommentChanged);
    on<WriteReviewSubmitted>(_onSubmitted);
    on<WriteReviewFailureCleared>(_onFailureCleared);
  }

  final ReviewRepository _reviews;
  final BookingRepository _bookings;

  Future<void> _onStarted(
    WriteReviewStarted event,
    Emitter<WriteReviewState> emit,
  ) async {
    emit(
      state.copyWith(
        bookingId: event.bookingId,
        status: DataStatus.loading,
        failure: () => null,
      ),
    );

    final result = await _bookings.byId(event.bookingId);
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(status: DataStatus.success, booking: () => value));
      case Err(:final failure):
        emit(
          state.copyWith(status: DataStatus.failure, failure: () => failure),
        );
    }
  }

  void _onRatingChanged(
    WriteReviewRatingChanged event,
    Emitter<WriteReviewState> emit,
  ) {
    emit(
      state.copyWith(
        draft: state.draft.copyWith(rating: event.rating),
        failure: () => null,
      ),
    );
  }

  void _onCommentChanged(
    WriteReviewCommentChanged event,
    Emitter<WriteReviewState> emit,
  ) {
    emit(
      state.copyWith(
        draft: state.draft.copyWith(comment: event.comment),
        failure: () => null,
      ),
    );
  }

  Future<void> _onSubmitted(
    WriteReviewSubmitted event,
    Emitter<WriteReviewState> emit,
  ) async {
    final bookingId = state.bookingId;
    if (bookingId == null || !state.canSubmit) return;

    emit(
      state.copyWith(
        submitStatus: ActionStatus.inProgress,
        failure: () => null,
      ),
    );

    final result = await _reviews.create(bookingId, state.draft);
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            submitStatus: ActionStatus.success,
            savedReview: () => value,
          ),
        );
      case Err(:final failure):
        // A 409 means this trip was already reviewed — the screen says so and
        // closes rather than inviting a retry.
        emit(
          state.copyWith(
            submitStatus: ActionStatus.failure,
            failure: () => failure,
          ),
        );
    }
  }

  void _onFailureCleared(
    WriteReviewFailureCleared event,
    Emitter<WriteReviewState> emit,
  ) {
    emit(state.copyWith(failure: () => null, submitStatus: ActionStatus.idle));
  }
}
