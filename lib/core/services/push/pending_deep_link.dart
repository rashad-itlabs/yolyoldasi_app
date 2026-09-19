import '../../../features/notifications/domain/entities/app_notification.dart';
import '../../router/app_routes.dart';
import 'push_message.dart';

/// Holds a notification tap until there is somewhere for it to land.
///
/// A tap can arrive before the app can act on it, and the gap is not small.
/// On a cold start the process launches, `SessionBloc` restores the token and
/// re-reads the profile, and until that finishes the router rewrites every
/// location to `/splash` — so navigating straight from the tap handler puts the
/// user on the splash screen and loses the destination.
///
/// So the tap is parked here and drained once the session is ready. The same
/// path is used for a warm tap, where the session is already ready and the
/// drain happens immediately: one code path rather than two, because the
/// cold-start one is the one that gets tested least and breaks most.
class PendingDeepLink {
  PushMessage? _pending;

  /// Whether a tap is waiting to be handled.
  bool get hasPending => _pending != null;

  /// Parks [message]. A newer tap replaces an older one — the user pressed the
  /// later notification, so that is the screen they asked for.
  void offer(PushMessage message) {
    _pending = message;
  }

  /// Takes the pending route, if any, and clears it.
  ///
  /// Returns null when nothing is waiting, or when the tap led nowhere —
  /// API.md §13 allows every id to be null at once, which is a notification
  /// whose subject has since been deleted.
  String? takeRoute() {
    final message = _pending;
    _pending = null;
    if (message == null) return null;
    return routeFor(message);
  }

  /// Takes the pending message itself, for a caller that needs more than the
  /// route — telling a dead link apart from an empty queue, for instance.
  PushMessage? take() {
    final message = _pending;
    _pending = null;
    return message;
  }

  void clear() => _pending = null;

  /// The conversation the user is looking at right now, or null.
  ///
  /// Set by the chat screen while it is on top. It exists so a push for the
  /// thread already open does not pop a banner over the message the user is
  /// watching arrive.
  ///
  /// This is only the belt-and-braces half. The real suppression is server
  /// side, because FCM demotes an app instance whose high-priority messages
  /// repeatedly draw nothing — so the heaviest chat users would be the first to
  /// stop getting notifications on a locked screen. What the server cannot
  /// cover is the gap between its presence heartbeat and now, which is this.
  int? openConversationId;

  bool isOpen(int? conversationId) =>
      conversationId != null && conversationId == openConversationId;

  /// Where a push leads, or null when it leads nowhere.
  ///
  /// Derived from [AppNotification.target] rather than from the push's own
  /// fields, so a tap on a banner and a tap on the same entry in the
  /// notification centre can never disagree.
  static String? routeFor(PushMessage message) => switch (message.target) {
    ConversationTarget(:final conversationId) => Routes.conversation(
      conversationId,
    ),
    BookingTarget(:final bookingId) => Routes.bookingDetail(bookingId),
    RideTarget(:final rideId) => Routes.rideDetail(rideId),
    _ => null,
  };
}
