import '../../../../core/error/result.dart';
import '../../../../core/network/api_envelope.dart';
import '../../../profile/domain/entities/user_enums.dart';
import '../../domain/entities/review.dart';
import '../../domain/repositories/review_repository.dart';
import '../services/review_api_service.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  const ReviewRepositoryImpl(this._api);

  final ReviewApiService _api;

  @override
  FutureResult<Review> create(int bookingId, ReviewDraft draft) =>
      _api.create(bookingId, draft);

  @override
  FutureResult<Paginated<Review>> forUser(
    int userId, {
    UserMode? role,
    int? page,
  }) => _api.forUser(userId, role: role, page: page);
}
