import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/json_reader.dart';
import '../../domain/entities/conversation.dart';
import '../models/chat_model.dart';

/// `/conversations` — API.md §11.
class ChatApiService {
  const ChatApiService(this._client);

  final ApiClient _client;

  FutureResult<Paginated<Conversation>> conversations({int? page}) =>
      _client.getPage(
        Api.conversations,
        page: page,
        parse: ConversationModel.fromJson,
      );

  /// 50 per page, **newest first**. The chat screen reverses the list
  /// (API.md §11).
  FutureResult<Paginated<ChatMessage>> messages(
    int conversationId, {
    int? page,
  }) => _client.getPage(
    Api.conversationMessages(conversationId),
    page: page,
    parse: ChatMessageModel.fromJson,
  );

  /// 422 when the conversation is locked.
  FutureResult<ChatMessage> send(int conversationId, String text) =>
      _client.post(
        Api.conversationMessages(conversationId),
        body: ChatMessageModel.sendBody(text),
        parse: ChatMessageModel.fromJson,
      );

  /// Zeroes the unread counter and stamps `read_at` on the other side's
  /// messages. Called when the chat screen opens.
  FutureResult<void> markRead(int conversationId) =>
      _client.send('POST', Api.conversationRead(conversationId));

  /// `{ "unread_total": 5 }` — the badge in the navigation bar.
  FutureResult<int> unreadTotal() => _client.getObject(
    Api.conversationsUnreadCount,
    parse: (json) => json.integer('unread_total'),
  );
}
