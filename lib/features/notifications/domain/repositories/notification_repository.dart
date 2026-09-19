import '../../../../core/error/result.dart';
import '../../../../core/network/api_envelope.dart';
import '../entities/app_notification.dart';

/// The in-app notification centre — API.md §13.
///
/// Push delivery is not live on the backend yet; these endpoints are what fill
/// the list today, and the payload shape will not change when FCM is switched
/// on.
abstract interface class NotificationRepository {
  FutureResult<Paginated<AppNotification>> list({
    bool unreadOnly = false,
    int? page,
  });

  FutureResult<int> unreadTotal();

  FutureResult<void> markRead(int notificationId);

  FutureResult<void> markAllRead();
}
