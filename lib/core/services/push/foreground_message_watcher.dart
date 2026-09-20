import 'dart:async';

import '../../../features/chat/domain/repositories/chat_repository.dart';
import '../../../features/notifications/domain/entities/app_notification.dart';
import '../../config/app_config.dart';
import 'pending_deep_link.dart';
import 'push_message.dart';

/// Notices a new message while the app is open but the user is somewhere else.
///
/// This is the half of "notify me about messages" that needs no push transport
/// at all: the app is running, so it can simply ask. It re-reads
/// `GET /conversations` (API.md §11) on a timer and raises a notification for
/// any thread whose last message is newer than the one it saw last — unless
/// that thread is the one on screen.
///
/// **It covers exactly one case: the app in the foreground.** A backgrounded or
/// killed app runs no Dart at all, so no timer fires and nothing here happens.
/// The locked-phone case is structurally out of reach for any client-side
/// approach and needs a push transport; see [PushService].
///
/// It emits [PushMessage] rather than some local type so that a message found
/// by polling and a message delivered by push travel the same path and are
/// rendered by the same code. When a transport is wired, this keeps working as
/// the gap-filler and nothing downstream changes.
class ForegroundMessageWatcher {
  ForegroundMessageWatcher({
    required ChatRepository chat,
    required PendingDeepLink deepLink,
  }) : _chat = chat,
       _deepLink = deepLink;

  final ChatRepository _chat;
  final PendingDeepLink _deepLink;

  final StreamController<PushMessage> _controller =
      StreamController<PushMessage>.broadcast();

  Timer? _timer;
  int? _userId;

  /// The last message time this watcher has already accounted for, per
  /// conversation. Seeded by the first poll so that opening the app does not
  /// fire a notification for every message that arrived while it was closed —
  /// those are the push transport's job, not this one's.
  final Map<int, DateTime> _seen = {};
  bool _seeded = false;

  Stream<PushMessage> get messages => _controller.stream;

  bool get isRunning => _timer != null;

  /// Begins watching on behalf of [userId], whose own messages are ignored.
  ///
  /// Safe to call repeatedly: a second call for the same user is a no-op, and
  /// a call for a different user starts over with a fresh baseline.
  void start({required int userId}) {
    if (_timer != null && _userId == userId) return;

    if (_userId != userId) {
      _seen.clear();
      _seeded = false;
      _userId = userId;
    }

    _timer?.cancel();
    _timer = Timer.periodic(
      AppConfig.foregroundMessageCheck,
      (_) => unawaited(checkNow()),
    );

    // The first pass only establishes the baseline, so there is no reason to
    // make the user wait a full interval for it.
    unawaited(checkNow());
  }

  /// Runs one pass immediately, off the timer.
  ///
  /// Worth calling whenever something has probably changed — coming back to the
  /// foreground, closing a thread — rather than waiting out the interval.
  Future<void> checkNow() => _check();

  /// Stops the timer but keeps the baseline, so returning from the background
  /// does not replay everything that arrived while away.
  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  /// Stops and forgets everything — used on sign-out, so the next account
  /// starts with a clean baseline rather than inheriting one.
  void stop() {
    pause();
    _seen.clear();
    _seeded = false;
    _userId = null;
  }

  Future<void> _check() async {
    final userId = _userId;
    if (userId == null) return;

    final page = (await _chat.conversations()).valueOrNull;

    // A failed read changes nothing — not the baseline either, or the first
    // message after a blip would be written off as already seen.
    if (page == null) return;

    final conversations = page.items;
    final wasSeeded = _seeded;
    _seeded = true;

    for (final conversation in conversations) {
      final at = conversation.lastMessageAt;
      if (at == null) continue;

      final previous = _seen[conversation.id];
      _seen[conversation.id] = at;

      // Baseline pass: record where every thread stands, announce nothing.
      if (!wasSeeded) continue;

      if (previous != null && !at.isAfter(previous)) continue;

      // Their own message coming back from the server is not news.
      if (conversation.isLastSender(userId)) continue;

      // Already read it somewhere — another device, or the list screen.
      if (!conversation.hasUnread) continue;

      // Reading that very thread right now: the message is about to appear in
      // the list on its own.
      if (_deepLink.isOpen(conversation.id)) continue;

      _controller.add(
        PushMessage(
          type: NotificationType.newMessage,
          conversationId: conversation.id,
          rideId: conversation.rideId,
          bookingId: conversation.bookingId,
          actorName: conversation.otherUser?.fullName,
          body: conversation.lastMessage.isEmpty
              ? null
              : conversation.lastMessage,
          sentAt: at,
        ),
      );
    }
  }

  Future<void> dispose() async {
    pause();
    await _controller.close();
  }
}
