part of 'public_profile_bloc.dart';

sealed class PublicProfileEvent extends Equatable {
  const PublicProfileEvent();

  @override
  List<Object?> get props => const [];
}

class PublicProfileRequested extends PublicProfileEvent {
  const PublicProfileRequested(this.userId);

  final int userId;

  @override
  List<Object?> get props => [userId];
}

/// Switches the review list between "as a driver" and "as a passenger".
/// `null` shows both (API.md §12).
class PublicProfileRoleChanged extends PublicProfileEvent {
  const PublicProfileRoleChanged(this.role);

  final UserMode? role;

  @override
  List<Object?> get props => [role];
}

class PublicProfileMoreReviewsRequested extends PublicProfileEvent {
  const PublicProfileMoreReviewsRequested();
}
