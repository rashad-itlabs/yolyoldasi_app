import 'package:equatable/equatable.dart';

import '../../../profile/domain/entities/app_user.dart';
import '../../../profile/domain/entities/user_enums.dart';

/// A rating one party left for the other after a completed trip —
/// `GET /users/{id}/reviews` (API.md §12).
class Review extends Equatable {
  const Review({
    required this.id,
    required this.rating,
    required this.authorWasDriver,
    required this.createdAt,
    this.author,
    this.comment = '',
  });

  final int id;

  /// 1–5.
  final int rating;

  /// Which hat the **author** wore — not the person being reviewed
  /// (API.md §12). `false` means a passenger wrote it, so the review is about
  /// a driver.
  final bool authorWasDriver;

  final DateTime createdAt;

  /// Nullable: a deleted author leaves the block out.
  final PublicUser? author;

  final String comment;

  /// The role the review is *about*.
  UserMode get targetRole =>
      authorWasDriver ? UserMode.passenger : UserMode.driver;

  bool get isAboutDriver => !authorWasDriver;

  bool get hasComment => comment.trim().isNotEmpty;

  @override
  List<Object?> get props => [
    id,
    rating,
    authorWasDriver,
    createdAt,
    author,
    comment,
  ];
}

/// Rolled-up rating for a profile header: average plus the star histogram.
///
/// Built on the client from a loaded page of reviews — the API exposes the
/// averages on `stats` but not the distribution.
class RatingSummary extends Equatable {
  const RatingSummary({
    required this.average,
    required this.count,
    required this.histogram,
  });

  final double average;
  final int count;

  /// Star value (1–5) to how many reviews gave it.
  final Map<int, int> histogram;

  static const RatingSummary empty = RatingSummary(
    average: 0,
    count: 0,
    histogram: {},
  );

  factory RatingSummary.fromReviews(List<Review> reviews) {
    if (reviews.isEmpty) return empty;
    final histogram = <int, int>{};
    var total = 0;
    for (final review in reviews) {
      total += review.rating;
      histogram[review.rating] = (histogram[review.rating] ?? 0) + 1;
    }
    return RatingSummary(
      average: total / reviews.length,
      count: reviews.length,
      histogram: histogram,
    );
  }

  /// Share of reviews at [stars], as a 0–1 fraction for the bar chart.
  double fractionOf(int stars) =>
      count == 0 ? 0 : (histogram[stars] ?? 0) / count;

  @override
  List<Object?> get props => [average, count, histogram];
}

/// What the review form collects for `POST /bookings/{id}/reviews`.
///
/// The API works out who is reviewing whom from the booking, so neither the
/// target nor the role is sent (API.md §12).
class ReviewDraft extends Equatable {
  const ReviewDraft({this.rating = 0, this.comment = ''});

  final int rating;
  final String comment;

  bool get isValid => rating >= 1 && rating <= 5;

  ReviewDraft copyWith({int? rating, String? comment}) => ReviewDraft(
    rating: rating ?? this.rating,
    comment: comment ?? this.comment,
  );

  @override
  List<Object?> get props => [rating, comment];
}
