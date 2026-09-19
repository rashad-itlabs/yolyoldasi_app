import '../../../../core/network/json_reader.dart';
import '../../../../core/types.dart';
import '../../../profile/data/models/user_model.dart';
import '../../domain/entities/app_notification.dart';

/// The notification object in API.md §13.
abstract final class NotificationModel {
  static AppNotification fromJson(Json json) {
    return AppNotification(
      id: json.integer('id'),
      type: NotificationType.fromApi(json.strOrNull('type')),
      createdAt: json.date('created_at'),
      // All three may be null when the related object has been deleted.
      rideId: json.integerOrNull('ride_id'),
      bookingId: json.integerOrNull('booking_id'),
      conversationId: json.integerOrNull('conversation_id'),
      actor: PublicUserModel.fromJsonOrNull(json.childOrNull('actor')),
      payload: json.child('payload'),
      readAt: json.dateOrNull('read_at'),
    );
  }
}
