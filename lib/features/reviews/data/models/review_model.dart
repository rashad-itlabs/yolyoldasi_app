import '../../../../core/network/json_reader.dart';
import '../../../../core/types.dart';
import '../../../profile/data/models/user_model.dart';
import '../../domain/entities/review.dart';

/// The review object in API.md §12.
abstract final class ReviewModel {
  static Review fromJson(Json json) {
    return Review(
      id: json.integer('id'),
      rating: json.integer('rating'),
      authorWasDriver: json.flag('author_was_driver'),
      createdAt: json.date('created_at'),
      author: PublicUserModel.fromJsonOrNull(json.childOrNull('author')),
      comment: json.str('comment'),
    );
  }

  /// Body for `POST /bookings/{id}/reviews`.
  static Json createBody(ReviewDraft draft) => {
    'rating': draft.rating,
    'comment': ?_blankToNull(draft.comment),
  };

  static String? _blankToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
