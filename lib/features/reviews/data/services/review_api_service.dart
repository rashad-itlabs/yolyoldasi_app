import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_envelope.dart';
import '../../../profile/domain/entities/user_enums.dart';
import '../../domain/entities/review.dart';
import '../models/review_model.dart';

/// Reviews — API.md §12.
class ReviewApiService {
  const ReviewApiService(this._client);

  final ApiClient _client;

  /// `POST /bookings/{id}/reviews`
  ///
  /// Only a `completed` booking may be reviewed, and a second attempt on the
  /// same trip is a 409.
  FutureResult<Review> create(int bookingId, ReviewDraft draft) => _client.post(
    Api.bookingReviews(bookingId),
    body: ReviewModel.createBody(draft),
    parse: ReviewModel.fromJson,
  );

  /// `GET /users/{id}/reviews`
  ///
  /// [role] filters by the role the person was reviewed *in*: `driver` returns
  /// the reviews they collected as a driver. Omitting it returns both.
  FutureResult<Paginated<Review>> forUser(
    int userId, {
    UserMode? role,
    int? page,
  }) => _client.getPage(
    Api.userReviews(userId),
    query: {'role': ?role?.apiValue},
    page: page,
    parse: ReviewModel.fromJson,
  );
}
