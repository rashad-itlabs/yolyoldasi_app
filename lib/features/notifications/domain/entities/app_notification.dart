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
  documentsRejected,

  /// A ride appeared on a route the passenger had posted a request for
  /// (API.md §19). Carries `ride_id`, so the tap opens that ride.
  rideRequestMatched,

  /// Someone is looking for a seat on a route this driver runs (API.md §19).
  /// Carries no ids — the tap opens the incoming-requests list instead.
  rideRequestPosted,

  /// Written by hand in the admin panel — a service notice.
  adminMessage,

  /// Written by hand in the admin panel — a promotion.
  ///
  /// Separate from [adminMessage] only because of which preference silences
  /// it: a notice about scheduled downtime answers to `push_enabled`, a
  /// promotion also to `marketing`.
  adminMarketing,

  /// A wire value this build does not know — a newer server, or a typo.
  ///
  /// Explicit rather than folded into a real type. The previous fallback
  /// answered every unrecognised value with `bookingRequested`, so a renamed
  /// or mistyped type rendered a chat message as a booking request and routed
  /// the tap to the wrong screen, silently. A type the app cannot place is now
  /// something it can say out loud.
  unknown;

  String get apiValue => name;

  bool get isKnown => this != NotificationType.unknown;

  /// Whether the notification carries its own wording and leads nowhere.
  ///
  /// The two admin types are the exception to almost every rule in this file:
  /// their text is written by a person and travels in `payload`, rather than
  /// being a localized line the app picks from [titleKey]; and all three
  /// deep-link ids are null *by design*, not because the subject was deleted.
  /// Code that treats "no target" as a broken link has to ask this first.
  bool get isAnnouncement =>
      this == NotificationType.adminMessage ||
      this == NotificationType.adminMarketing;

  /// Localization key for the notification title.
  ///
  /// For an announcement this is only the fallback, used when the admin's own
  /// heading is missing.
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
    NotificationType.rideRequestMatched => 'notifRideRequestMatchedTitle',
    NotificationType.rideRequestPosted => 'notifRideRequestPostedTitle',
    NotificationType.adminMessage => 'notifAdminMessageTitle',
    NotificationType.adminMarketing => 'notifAdminMarketingTitle',
    NotificationType.unknown => 'notifUnknownTitle',
  };

  static NotificationType fromApi(String? value) =>
      NotificationType.values.firstWhere(
        (t) => t.apiValue == value,
        orElse: () => NotificationType.unknown,
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

/// The driver's incoming ride requests.
///
/// The one target that is not an object id: `rideRequestPosted` is about a
/// route rather than a single row, and sending the driver to one stranger's
/// request would be narrower than what the notification promised.
class RideRequestsTarget extends NotificationTarget {
  const RideRequestsTarget();
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
    if (type == NotificationType.rideRequestPosted) {
      return const RideRequestsTarget();
    }
    if (conversationId != null && type == NotificationType.newMessage) {
      return ConversationTarget(conversationId!);
    }
    if (bookingId != null) return BookingTarget(bookingId!);
    if (rideId != null) return RideTarget(rideId!);
    if (conversationId != null) return ConversationTarget(conversationId!);
    return NotificationTarget.none;
  }

  /// Nothing to open, *and* nothing should have been.
  ///
  /// An announcement has no ids either, but that is how it is meant to be —
  /// calling it a dead link would strike out a perfectly good notice in the
  /// list and answer a tap on it with "this no longer exists".
  bool get isDeadLink => target is _NoTarget && !type.isAnnouncement;

  /// The admin's own title, for the types that carry one (API.md §13).
  ///
  /// Null for every other type, whose title is a localized line chosen by
  /// [NotificationType.titleKey] instead.
  String? get heading => _text('heading');

  /// The admin's own body text. See [heading].
  String? get body => _text('content');

  String? _text(String key) {
    if (!type.isAnnouncement) return null;
    final value = payload[key];
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

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
