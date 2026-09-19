import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/data_status.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/result.dart';
import '../../../../../core/network/api_envelope.dart';
import '../../../domain/entities/app_notification.dart';
import '../../../domain/repositories/notification_repository.dart';

part 'notifications_event.dart';
part 'notifications_state.dart';

/// `GET /notifications` — the notification centre (API.md §13).
class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  NotificationsBloc({required NotificationRepository notifications})
    : _notifications = notifications,
      super(const NotificationsState()) {
    on<NotificationsRequested>(_onRequested, transformer: restartable());
    on<NotificationsFilterChanged>(
      _onFilterChanged,
      transformer: restartable(),
    );
    on<NotificationsMoreRequested>(_onMoreRequested, transformer: droppable());
    on<NotificationRead>(_onRead);
    on<NotificationsAllRead>(_onAllRead);
  }

  final NotificationRepository _notifications;

  Future<void> _onRequested(
    NotificationsRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    emit(
      state.copyWith(
        status: state.page.isNotEmpty && event.refresh
            ? DataStatus.refreshing
            : DataStatus.loading,
        failure: () => null,
      ),
    );
    await _load(emit);
  }

  Future<void> _onFilterChanged(
    NotificationsFilterChanged event,
    Emitter<NotificationsState> emit,
  ) async {
    if (state.unreadOnly == event.unreadOnly) return;
    emit(
      state.copyWith(
        unreadOnly: event.unreadOnly,
        status: DataStatus.loading,
        failure: () => null,
      ),
    );
    await _load(emit);
  }

  Future<void> _load(Emitter<NotificationsState> emit) async {
    final result = await _notifications.list(unreadOnly: state.unreadOnly);
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(status: DataStatus.success, page: value));
      case Err(:final failure):
        emit(
          state.copyWith(status: DataStatus.failure, failure: () => failure),
        );
    }
  }

  Future<void> _onMoreRequested(
    NotificationsMoreRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    if (!state.page.hasMore || state.isLoadingMore || state.status.isBusy) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true));

    final result = await _notifications.list(
      unreadOnly: state.unreadOnly,
      page: state.page.nextPage,
    );
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(isLoadingMore: false, page: state.page.concat(value)),
        );
      case Err(:final failure):
        emit(state.copyWith(isLoadingMore: false, failure: () => failure));
    }
  }

  Future<void> _onRead(
    NotificationRead event,
    Emitter<NotificationsState> emit,
  ) async {
    // A deep link can bring the user to a notification that is not in the
    // loaded page, so a miss is normal rather than an error.
    final index = state.page.items.indexWhere(
      (n) => n.id == event.notificationId,
    );
    if (index != -1 && state.page.items[index].isRead) return;

    // Optimistic: tapping a row should dim it immediately, and the call is
    // idempotent, so a failure costs nothing but a stale badge until the next
    // refresh.
    emit(state.copyWith(page: _markRead(event.notificationId)));
    await _notifications.markRead(event.notificationId);
  }

  Future<void> _onAllRead(
    NotificationsAllRead event,
    Emitter<NotificationsState> emit,
  ) async {
    if (state.unreadCount == 0) return;

    final previous = state.page;
    emit(
      state.copyWith(
        page: state.page.replacingItems([
          for (final notification in state.page.items)
            notification.isRead
                ? notification
                : notification.copyWith(readAt: DateTime.now),
        ]),
      ),
    );

    final result = await _notifications.markAllRead();
    if (result case Err(:final failure)) {
      emit(state.copyWith(page: previous, failure: () => failure));
    }
  }

  Paginated<AppNotification> _markRead(int notificationId) =>
      state.page.replacingItems([
        for (final notification in state.page.items)
          if (notification.id == notificationId)
            notification.copyWith(readAt: DateTime.now)
          else
            notification,
      ]);
}
