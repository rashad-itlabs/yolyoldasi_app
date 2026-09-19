import '../../../../core/error/result.dart';
import '../../../../core/network/api_envelope.dart';
import '../entities/conversation.dart';

/// Messaging — API.md §11.
abstract interface class ChatRepository {
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
