import '../../../../core/error/result.dart';
import '../../../../core/network/api_envelope.dart';
import '../entities/conversation.dart';

/// Messaging — API.md §11.
abstract interface class ChatRepository {
  /// Fires with a conversation id each time [markRead] succeeded for it.
  ///
  /// Reading a thread changes counts that other screens hold: the message
  /// badge, the notification bell — the server marks the thread's
  /// `newMessage` notifications read in the same call (API.md §11) — the row
  /// in the conversation list, and those notification rows. All of them
  /// outlive the chat screen, and a thread can be opened from five places, so
  /// the read announces itself here rather than each route remembering to
  /// refresh. Same idea as `RideRepository.changes`.
  ///
  /// Nothing fires for a failed call: the server still counts the thread as
  /// unread, and so should every badge.
  Stream<int> get threadsRead;

  FutureResult<Paginated<Conversation>> conversations({int? page});

  /// One page of messages, newest first as the API returns them. Reversing for
  /// display is the chat screen's job.
  FutureResult<Paginated<ChatMessage>> messages(
    int conversationId, {
    int? page,
  });

  /// 422 when the thread is locked, which happens once the booking is rejected
  /// or cancelled.
  FutureResult<ChatMessage> send(int conversationId, String text);

  FutureResult<void> markRead(int conversationId);

  /// Total unread messages across every thread, for the tab badge.
  FutureResult<int> unreadTotal();
}
