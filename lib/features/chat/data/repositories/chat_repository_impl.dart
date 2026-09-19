import '../../../../core/error/result.dart';
import '../../../../core/network/api_envelope.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';
import '../services/chat_api_service.dart';

class ChatRepositoryImpl implements ChatRepository {
  const ChatRepositoryImpl(this._api);

  final ChatApiService _api;

  @override
  FutureResult<Paginated<Conversation>> conversations({int? page}) =>
      _api.conversations(page: page);

  @override
  FutureResult<Paginated<ChatMessage>> messages(
    int conversationId, {
    int? page,
  }) => _api.messages(conversationId, page: page);

  @override
  FutureResult<ChatMessage> send(int conversationId, String text) =>
      _api.send(conversationId, text);

  @override
  FutureResult<void> markRead(int conversationId) =>
      _api.markRead(conversationId);

  @override
  FutureResult<int> unreadTotal() => _api.unreadTotal();
}
