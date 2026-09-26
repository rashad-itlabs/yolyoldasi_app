import 'dart:async';

import '../../../../core/error/result.dart';
import '../../../../core/network/api_envelope.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../services/notification_api_service.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this._api);

  final NotificationApiService _api;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  /// Passes [write] through, announcing it on [changes] when it succeeded.
  Future<Result<T>> _announce<T>(Future<Result<T>> write) async {
    final result = await write;
    if (result.isOk) _changes.add(null);
    return result;
  }

  @override
  FutureResult<Paginated<AppNotification>> list({
    bool unreadOnly = false,
    int? page,
  }) => _api.list(unreadOnly: unreadOnly, page: page);

  @override
  FutureResult<int> unreadTotal() => _api.unreadTotal();

  @override
  FutureResult<void> markRead(int notificationId) =>
      _announce(_api.markRead(notificationId));

  @override
  FutureResult<void> markAllRead() => _announce(_api.markAllRead());
}
