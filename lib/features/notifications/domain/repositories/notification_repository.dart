import '../../../../core/error/result.dart';
import '../../../../core/network/api_envelope.dart';
import '../entities/app_notification.dart';

/// The in-app notification centre — API.md §13.
///
/// Push delivery is not live on the backend yet; these endpoints are what fill
/// the list today, and the payload shape will not change when FCM is switched
/// on.
abstract interface class NotificationRepository {
  /// Fires after [markRead] or [markAllRead] succeeded.
  ///
  /// The bell is `GET /notifications/unread-count`, so it has to be re-read
  /// *after* the write has landed. Asking for it from the tap that starts the
  /// write races the write, and a count taken before the write commits comes
  /// back unchanged — the row reads as read but the bell does not drop.
  Stream<void> get changes;

  FutureResult<Paginated<AppNotification>> list({
    bool unreadOnly = false,
    int? page,
  });

  FutureResult<int> unreadTotal();

  FutureResult<void> markRead(int notificationId);

  FutureResult<void> markAllRead();
}
