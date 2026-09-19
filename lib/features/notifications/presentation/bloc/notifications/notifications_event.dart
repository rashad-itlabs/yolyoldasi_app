part of 'notifications_bloc.dart';

sealed class NotificationsEvent extends Equatable {
  const NotificationsEvent();

  @override
  List<Object?> get props => const [];
}

class NotificationsRequested extends NotificationsEvent {
  const NotificationsRequested({this.refresh = false});

  final bool refresh;

  @override
  List<Object?> get props => [refresh];
}

/// Toggles `?unread=1`.
class NotificationsFilterChanged extends NotificationsEvent {
  const NotificationsFilterChanged({required this.unreadOnly});

  final bool unreadOnly;

  @override
  List<Object?> get props => [unreadOnly];
}

class NotificationsMoreRequested extends NotificationsEvent {
  const NotificationsMoreRequested();
}

/// `POST /notifications/{id}/read`, fired when a row is tapped.
class NotificationRead extends NotificationsEvent {
  const NotificationRead(this.notificationId);

  final int notificationId;

  @override
  List<Object?> get props => [notificationId];
}

/// `POST /notifications/read-all`.
class NotificationsAllRead extends NotificationsEvent {
  const NotificationsAllRead();
}
