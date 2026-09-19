import '../../../features/notifications/domain/entities/app_notification.dart';

/// The Android notification channels this app creates, and which notification
/// lands in which.
///
/// **An channel's importance is frozen when the channel is first created.** No
/// app update can raise it afterwards — Android only lets the *user* change it,
/// and only downwards in practice. So every channel that might ever need to
/// interrupt is created at [ChannelImportance.high] on day one, and the one
/// that must never interrupt is created low and stays there. Getting this wrong
/// in the first shipped build is unfixable for everyone who installs it.
///
/// The split follows the preference categories the API already defines
/// (API.md §4: `bookings`, `messages`, `reminders`, `marketing`, under the
/// master `push_enabled`), so a user muting a category in the OS and muting it
/// in the app are muting the same thing.
enum PushChannel {
  /// Chat. The case push exists for: it must reach a locked screen.
  messages('yolyoldasi_messages', ChannelImportance.high),

  /// A seat confirmed, declined or cancelled — someone is waiting on the
  /// answer, and a trip may be about to fall through.
  bookings('yolyoldasi_bookings', ChannelImportance.high),

  /// "Your trip leaves in an hour." Time-critical by definition; a reminder
  /// that waits for the next time the user unlocks is a reminder that failed.
  reminders('yolyoldasi_reminders', ChannelImportance.high),

  /// Promotions. Must never interrupt, and there is no future in which it
  /// should — which is the only reason it is safe to freeze this one low.
  marketing('yolyoldasi_marketing', ChannelImportance.low),

  /// Account notices, and anything this build does not recognise.
  ///
  /// Named to match `default_notification_channel_id` in AndroidManifest.xml:
  /// FCM falls back to that channel when a payload names none, so it has to be
  /// a channel that actually exists and can be seen.
  fallback('yolyoldasi_default', ChannelImportance.high);

  const PushChannel(this.id, this.importance);

  final String id;
  final ChannelImportance importance;

  /// Which channel carries [type].
  ///
  /// Unknown types land in [fallback] rather than being dropped: a server that
  /// learns a new notification type before the app does should still be able to
  /// reach the user.
  static PushChannel forType(NotificationType type) => switch (type) {
    NotificationType.newMessage => PushChannel.messages,
    NotificationType.bookingRequested ||
    NotificationType.bookingConfirmed ||
    NotificationType.bookingRejected ||
    NotificationType.bookingCancelled ||
    NotificationType.rideCancelled ||
    NotificationType.reviewRequest => PushChannel.bookings,
    NotificationType.rideReminder => PushChannel.reminders,
    NotificationType.documentsApproved ||
    NotificationType.documentsRejected ||
    NotificationType.unknown => PushChannel.fallback,
  };

  /// The localization key for the channel's name, as it appears in the Android
  /// system settings list.
  String get nameKey => switch (this) {
    PushChannel.messages => 'channelMessages',
    PushChannel.bookings => 'channelBookings',
    PushChannel.reminders => 'channelReminders',
    PushChannel.marketing => 'channelMarketing',
    PushChannel.fallback => 'channelGeneral',
  };

  String get descriptionKey => switch (this) {
    PushChannel.messages => 'channelMessagesDesc',
    PushChannel.bookings => 'channelBookingsDesc',
    PushChannel.reminders => 'channelRemindersDesc',
    PushChannel.marketing => 'channelMarketingDesc',
    PushChannel.fallback => 'channelGeneralDesc',
  };
}

/// Kept separate from the plugin's own enum so this file — and the decision it
/// records — does not depend on the notification package.
enum ChannelImportance { high, normal, low }
