part of 'recent_searches_bloc.dart';

class RecentSearchesState extends Equatable {
  const RecentSearchesState({
    this.status = DataStatus.initial,
    this.searches = const [],
    this.failure,
  });

  final DataStatus status;
  final List<RecentSearch> searches;
  final Failure? failure;

  bool get hasSearches => searches.isNotEmpty;

  /// The chips worth offering: at most five, so the row never wraps.
  List<RecentSearch> get visible => searches.take(5).toList(growable: false);

  RecentSearchesState copyWith({
    DataStatus? status,
    List<RecentSearch>? searches,
    Failure? Function()? failure,
  }) {
    return RecentSearchesState(
      status: status ?? this.status,
      searches: searches ?? this.searches,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [status, searches, failure];
}
