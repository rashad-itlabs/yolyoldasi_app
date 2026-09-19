part of 'ride_browse_bloc.dart';

class RideBrowseState extends Equatable {
  const RideBrowseState({
    this.status = DataStatus.initial,
    this.page = const Paginated<Ride>.empty(),
    this.isLoadingMore = false,
    this.failure,
  });

  final DataStatus status;

  /// Everything loaded so far, exactly as the API sent it, with its cursor.
  final Paginated<Ride> page;

  final bool isLoadingMore;
  final Failure? failure;

  /// What the list shows. A departure that has come and gone is not an offer
  /// any more, so it drops out whether or not the server has caught up.
  List<Ride> get rides => page.items.upcomingOnly;

  bool get hasMore => page.hasMore;
  bool get isEmpty => status.isSuccess && rides.isEmpty;

  /// Whether the server refused the query itself rather than failing to answer
  /// it. A 422 on the first page means it still insists on `from_city_id` and
  /// `to_city_id` (API.md §9), so browsing without a route is a feature it does
  /// not have yet — not something the passenger did or can retry.
  bool get isUnsupported =>
      status.isFailure && page.isEmpty && failure is ValidationFailure;

  int get totalFound => page.meta.total;

  RideBrowseState copyWith({
    DataStatus? status,
    Paginated<Ride>? page,
    bool? isLoadingMore,
    Failure? Function()? failure,
  }) {
    return RideBrowseState(
      status: status ?? this.status,
      page: page ?? this.page,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [status, page, isLoadingMore, failure];
}
