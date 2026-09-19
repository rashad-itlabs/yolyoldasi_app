part of 'notifications_bloc.dart';

class NotificationsState extends Equatable {
  const NotificationsState({
    this.status = DataStatus.initial,
    this.page = const Paginated<AppNotification>.empty(),
    this.unreadOnly = false,
    this.isLoadingMore = false,
    this.failure,
  });

  final DataStatus status;
  final Paginated<AppNotification> page;
  final bool unreadOnly;
  final bool isLoadingMore;
  final Failure? failure;

  List<AppNotification> get notifications => page.items;
  bool get isEmpty => status.isSuccess && notifications.isEmpty;
  bool get hasMore => page.hasMore;

  /// Unread among the rows currently loaded. The authoritative figure for the
  /// badge is `GET /notifications/unread-count`, which [BadgesBloc] owns; this
  /// only decides whether "mark all read" is worth offering.
  int get unreadCount => notifications.where((n) => !n.isRead).length;

  NotificationsState copyWith({
    DataStatus? status,
    Paginated<AppNotification>? page,
    bool? unreadOnly,
    bool? isLoadingMore,
    Failure? Function()? failure,
  }) {
    return NotificationsState(
      status: status ?? this.status,
      page: page ?? this.page,
      unreadOnly: unreadOnly ?? this.unreadOnly,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [status, page, unreadOnly, isLoadingMore, failure];
}
