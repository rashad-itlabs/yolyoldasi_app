part of 'public_profile_bloc.dart';

class PublicProfileState extends Equatable {
  const PublicProfileState({
    this.status = DataStatus.initial,
    this.reviewsStatus = DataStatus.initial,
    this.userId,
    this.user,
    this.reviews = const Paginated<Review>.empty(),
    this.role,
    this.failure,
  });

  final DataStatus status;

  /// Tracked separately so switching the role filter does not blank the header.
  final DataStatus reviewsStatus;

  final int? userId;
  final PublicUser? user;
  final Paginated<Review> reviews;

  /// `null` means "both roles".
  final UserMode? role;

  final Failure? failure;

  bool get hasReviews => reviews.isNotEmpty;

  /// The star distribution over the reviews loaded so far. The API gives the
  /// averages on `stats` but not the histogram, so it is built here.
  RatingSummary get summary => RatingSummary.fromReviews(reviews.items);

  /// The authoritative average for [role], straight from the profile's stats
  /// rather than from the page of reviews on screen.
  double get ratingForRole =>
      user?.stats.ratingFor(role ?? UserMode.driver) ?? 0;

  PublicProfileState copyWith({
    DataStatus? status,
    DataStatus? reviewsStatus,
    int? userId,
    PublicUser? Function()? user,
    Paginated<Review>? reviews,
    UserMode? Function()? role,
    Failure? Function()? failure,
  }) {
    return PublicProfileState(
      status: status ?? this.status,
      reviewsStatus: reviewsStatus ?? this.reviewsStatus,
      userId: userId ?? this.userId,
      user: user != null ? user() : this.user,
      reviews: reviews ?? this.reviews,
      role: role != null ? role() : this.role,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [
    status,
    reviewsStatus,
    userId,
    user,
    reviews,
    role,
    failure,
  ];
}
