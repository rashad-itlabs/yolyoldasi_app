part of 'ride_search_bloc.dart';

class RideSearchState extends Equatable {
  const RideSearchState({
    this.status = DataStatus.initial,
    this.query = const RideSearchQuery(),
    this.page = const Paginated<Ride>.empty(),
    this.isLoadingMore = false,
    this.failure,
  });

  final DataStatus status;
  final RideSearchQuery query;

  /// Everything loaded so far, unfiltered, with the API's cursor.
  final Paginated<Ride> page;

  final bool isLoadingMore;
  final Failure? failure;

  /// What the list actually shows: the loaded rides, narrowed by the filters
  /// `GET /rides` cannot express.
  List<Ride> get rides => query.refine(page.items);

  bool get hasMore => page.hasMore;
  bool get canSearch => query.hasRoute;

  bool get isEmpty => status.isSuccess && rides.isEmpty;

  /// Whether the empty list is the client-side filters' doing rather than the
  /// server's — which is worth saying, because clearing them would help.
  bool get isFilteredEmpty =>
      isEmpty && page.isNotEmpty && query.hasRefinements;

  int get totalFound => page.meta.total;

  RideSearchState copyWith({
    DataStatus? status,
    RideSearchQuery? query,
    Paginated<Ride>? page,
    bool? isLoadingMore,
    Failure? Function()? failure,
  }) {
    return RideSearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      page: page ?? this.page,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [status, query, page, isLoadingMore, failure];
}
