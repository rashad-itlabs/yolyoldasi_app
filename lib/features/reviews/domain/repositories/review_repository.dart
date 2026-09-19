import '../../../../core/error/result.dart';
import '../../../../core/network/api_envelope.dart';
import '../../../profile/domain/entities/user_enums.dart';
import '../entities/review.dart';

/// Reviews — API.md §12.
abstract interface class ReviewRepository {
  /// `POST /bookings/{id}/reviews`. A second review on the same trip comes
  /// back as a [ConflictFailure].
  FutureResult<Review> create(int bookingId, ReviewDraft draft);

  /// `GET /users/{id}/reviews`, optionally narrowed to one role.
  FutureResult<Paginated<Review>> forUser(
    int userId, {
    UserMode? role,
    int? page,
  });
}
