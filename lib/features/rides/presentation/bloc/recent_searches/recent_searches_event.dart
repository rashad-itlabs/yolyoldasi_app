part of 'recent_searches_bloc.dart';

sealed class RecentSearchesEvent extends Equatable {
  const RecentSearchesEvent();

  @override
  List<Object?> get props => const [];
}

class RecentSearchesRequested extends RecentSearchesEvent {
  const RecentSearchesRequested();
}

/// `DELETE /me/recent-searches` — clears all ten.
class RecentSearchesCleared extends RecentSearchesEvent {
  const RecentSearchesCleared();
}
