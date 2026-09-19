import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/data_status.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/result.dart';
import '../../../../../core/network/api_envelope.dart';
import '../../../../reviews/domain/entities/review.dart';
import '../../../../reviews/domain/repositories/review_repository.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/entities/user_enums.dart';
import '../../../domain/repositories/user_repository.dart';

part 'public_profile_event.dart';
part 'public_profile_state.dart';

/// Somebody else's profile: `GET /users/{id}` plus their reviews.
///
/// The two reads are issued together because the screen is useless with only
/// one of them, and a 404 on either means the account is gone (API.md §1
/// counts deleted users as not found).
class PublicProfileBloc extends Bloc<PublicProfileEvent, PublicProfileState> {
  PublicProfileBloc({
    required UserRepository users,
    required ReviewRepository reviews,
  }) : _users = users,
       _reviews = reviews,
       super(const PublicProfileState()) {
    on<PublicProfileRequested>(_onRequested);
    on<PublicProfileRoleChanged>(_onRoleChanged);
    on<PublicProfileMoreReviewsRequested>(_onMoreReviewsRequested);
  }

  final UserRepository _users;
  final ReviewRepository _reviews;

  Future<void> _onRequested(
    PublicProfileRequested event,
    Emitter<PublicProfileState> emit,
  ) async {
    emit(
      state.copyWith(
        status: DataStatus.loading,
        // Both reads are in flight, so both statuses move. Leaving this on
        // `initial` left the review list showing its skeleton for good on
        // every profile that had nothing to show.
        reviewsStatus: DataStatus.loading,
        userId: event.userId,
        failure: () => null,
      ),
    );

    final results = await Future.wait([
      _users.publicProfile(event.userId),
      _reviews.forUser(event.userId, role: state.role),
    ]);

    final profile = results[0] as Result<PublicUser>;
    final reviews = results[1] as Result<Paginated<Review>>;

    if (profile case Err(:final failure)) {
      emit(
        state.copyWith(
          status: DataStatus.failure,
          reviewsStatus: DataStatus.failure,
          failure: () => failure,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: DataStatus.success,
        reviewsStatus: reviews.isOk ? DataStatus.success : DataStatus.failure,
        user: () => profile.valueOrNull,
        reviews: reviews.valueOrNull ?? const Paginated<Review>.empty(),
        // A profile that loaded with a failed review list is still worth
        // showing; the reviews section carries its own error state.
        failure: () => reviews.failureOrNull,
      ),
    );
  }

  Future<void> _onRoleChanged(
    PublicProfileRoleChanged event,
    Emitter<PublicProfileState> emit,
  ) async {
    final userId = state.userId;
    if (userId == null || state.role == event.role) return;

    emit(
      state.copyWith(
        role: () => event.role,
        reviewsStatus: DataStatus.loading,
        failure: () => null,
      ),
    );

    final result = await _reviews.forUser(userId, role: event.role);
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(reviewsStatus: DataStatus.success, reviews: value));
      case Err(:final failure):
        emit(
          state.copyWith(
            reviewsStatus: DataStatus.failure,
            failure: () => failure,
          ),
        );
    }
  }

  Future<void> _onMoreReviewsRequested(
    PublicProfileMoreReviewsRequested event,
    Emitter<PublicProfileState> emit,
  ) async {
    final userId = state.userId;
    if (userId == null ||
        !state.reviews.hasMore ||
        state.reviewsStatus.isBusy) {
      return;
    }

    emit(state.copyWith(reviewsStatus: DataStatus.refreshing));

    final result = await _reviews.forUser(
      userId,
      role: state.role,
      page: state.reviews.nextPage,
    );
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            reviewsStatus: DataStatus.success,
            reviews: state.reviews.concat(value),
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            reviewsStatus: DataStatus.success,
            failure: () => failure,
          ),
        );
    }
  }
}
