import '../../../../core/error/result.dart';
import '../../../../core/network/api_envelope.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../services/notification_api_service.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  const NotificationRepositoryImpl(this._api);

  final NotificationApiService _api;

  @override
  FutureResult<Paginated<AppNotification>> list({
    bool unreadOnly = false,
    int? page,
  }) => _api.list(unreadOnly: unreadOnly, page: page);

  @override
  FutureResult<int> unreadTotal() => _api.unreadTotal();

  @override
  FutureResult<void> markRead(int notificationId) =>
      _api.markRead(notificationId);

  @override
  FutureResult<void> markAllRead() => _api.markAllRead();
}
