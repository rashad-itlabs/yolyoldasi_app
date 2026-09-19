import 'package:equatable/equatable.dart';

import '../../../../core/types.dart';
import '../../../profile/domain/entities/app_user.dart';

/// Wire values from API.md §2 — these travel unchanged in the FCM payload's
/// `type` field, so the spellings are `camelCase` here and on the server.
enum NotificationType {
  bookingRequested,
  bookingConfirmed,
  bookingRejected,
  bookingCancelled,
  rideReminder,
  rideCancelled,
  newMessage,
  reviewRequest,
  documentsApproved,
  documentsRejected;

  String get apiValue => name;

  /// Localization key for the notification title.
  String get titleKey => switch (this) {
    NotificationType.bookingRequested => 'notifNewBookingTitle',
    NotificationType.bookingConfirmed => 'notifBookingConfirmedTitle',
    NotificationType.bookingRejected => 'notifBookingRejectedTitle',
    NotificationType.bookingCancelled => 'notifBookingCancelledTitle',
    NotificationType.rideReminder => 'notifRideReminderTitle',
    NotificationType.rideCancelled => 'notifRideCancelledTitle',
    NotificationType.newMessage => 'notifNewMessageTitle',
    NotificationType.reviewRequest => 'notifReviewRequestTitle',
    NotificationType.documentsApproved => 'notifDocsApprovedTitle',
    NotificationType.documentsRejected => 'notifDocsRejectedTitle',
  };

  static NotificationType fromApi(String? value) =>
      NotificationType.values.firstWhere(
        (t) => t.apiValue == value,
        orElse: () => NotificationType.bookingRequested,
      );
}

/// Where tapping a notification should go.
///
/// API.md §13 warns that all three ids can be null at once — the related
/// object may have been deleted — and asks the client to say "this no longer
/// exists" rather than opening a blank screen. [NotificationTarget.none] is
/// that case, made explicit so the tap handler cannot forget it.
sealed class NotificationTarget {
  const NotificationTarget();

  static const NotificationTarget none = _NoTarget();
}

class RideTarget extends NotificationTarget {
  const RideTarget(this.rideId);
  final int rideId;
}

class BookingTarget extends NotificationTarget {
  const BookingTarget(this.bookingId);
  final int bookingId;
}

class ConversationTarget extends NotificationTarget {
  const ConversationTarget(this.conversationId);
  final int conversationId;
}

class _NoTarget extends NotificationTarget {
  const _NoTarget();
}

/// A single entry in the notification centre — API.md §13.
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.type,
    required this.createdAt,
    this.rideId,
    this.bookingId,
    this.conversationId,
    this.actor,
    this.payload = const {},
    this.readAt,
  });

  final int id;
  final NotificationType type;
  final DateTime createdAt;

  // Deep-link targets — any or all may be null.
  final int? rideId;
  final int? bookingId;
  final int? conversationId;

  /// Who caused it, as a short profile.
  final PublicUser? actor;

  /// Type-specific extras, e.g. `{ "seats": 2 }`.
  final Json payload;

  final DateTime? readAt;

  bool get isRead => readAt != null;

  /// The most specific destination available, preferring the screen the
  /// notification is actually about.
  NotificationTarget get target {
    if (conversationId != null && type == NotificationType.newMessage) {
      return ConversationTarget(conversationId!);
    }
    if (bookingId != null) return BookingTarget(bookingId!);
    if (rideId != null) return RideTarget(rideId!);
    if (conversationId != null) return ConversationTarget(conversationId!);
    return NotificationTarget.none;
  }

  bool get isDeadLink => target is _NoTarget;

  /// Extras the title lines interpolate, e.g. the seat count.
  int? get seats {
    final value = payload['seats'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  AppNotification copyWith({DateTime? Function()? readAt}) {
    return AppNotification(
      id: id,
      type: type,
      createdAt: createdAt,
      rideId: rideId,
      bookingId: bookingId,
      conversationId: conversationId,
      actor: actor,
      payload: payload,
      readAt: readAt != null ? readAt() : this.readAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    createdAt,
    rideId,
    bookingId,
    conversationId,
    actor,
    readAt,
  ];
}
