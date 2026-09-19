import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/json_reader.dart';
import '../../domain/entities/app_notification.dart';
import '../models/notification_model.dart';

/// `/notifications` — API.md §13.
class NotificationApiService {
  const NotificationApiService(this._client);

  final ApiClient _client;

  /// 30 per page. [unreadOnly] maps to `?unread=1`.
  FutureResult<Paginated<AppNotification>> list({
    bool unreadOnly = false,
    int? page,
  }) => _client.getPage(
    Api.notifications,
    query: {'unread': ?(unreadOnly ? 1 : null)},
    page: page,
    parse: NotificationModel.fromJson,
  );

  /// `{ "unread_total": 3 }` — the bell badge.
  FutureResult<int> unreadTotal() => _client.getObject(
    Api.notificationsUnreadCount,
    parse: (json) => json.integer('unread_total'),
  );

  FutureResult<void> markRead(int notificationId) =>
      _client.send('POST', Api.notificationRead(notificationId));

  FutureResult<void> markAllRead() =>
      _client.send('POST', Api.notificationsReadAll);
}
