import '../../../../core/network/json_reader.dart';
import '../../../../core/types.dart';
import '../../../profile/data/models/user_model.dart';
import '../../domain/entities/conversation.dart';

/// `GET /conversations` (API.md §11).
abstract final class ConversationModel {
  static Conversation fromJson(Json json) {
    return Conversation(
      id: json.integer('id'),
      bookingId: json.integer('booking_id'),
      rideId: json.integer('ride_id'),
      otherUser: PublicUserModel.fromJsonOrNull(json.childOrNull('other_user')),
      lastMessage: json.str('last_message'),
      lastMessageAt: json.dateOrNull('last_message_at'),
      lastSenderId: json.integerOrNull('last_sender_id'),
      unreadCount: json.integer('unread_count'),
      isLocked: json.flag('is_locked'),
    );
  }
}

/// `GET|POST /conversations/{id}/messages` (API.md §11).
abstract final class ChatMessageModel {
  static ChatMessage fromJson(Json json) {
    return ChatMessage(
      id: json.integer('id'),
      senderId: json.integer('sender_id'),
      text: json.str('text'),
      createdAt: json.date('created_at'),
      isMine: json.flag('is_mine'),
      readAt: json.dateOrNull('read_at'),
    );
  }

  static Json sendBody(String text) => {'text': text.trim()};
}
