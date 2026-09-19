import 'package:equatable/equatable.dart';

import '../../../profile/domain/entities/app_user.dart';

/// A one-to-one thread tied to a booking — `GET /conversations` (API.md §11).
///
/// The API opens it together with the booking, so the two sides can write
/// before the driver has decided.
class Conversation extends Equatable {
  const Conversation({
    required this.id,
    required this.bookingId,
    required this.rideId,
    this.otherUser,
    this.lastMessage = '',
    this.lastMessageAt,
    this.lastSenderId,
    this.unreadCount = 0,
    this.isLocked = false,
  });

  final int id;
  final int bookingId;
  final int rideId;

  /// The counterpart's short profile. Nullable: a deleted account leaves the
  /// block out.
  final PublicUser? otherUser;

  final String lastMessage;
  final DateTime? lastMessageAt;

  /// Who sent [lastMessage] — used to show a "you:" prefix in the list.
  final int? lastSenderId;

  final int unreadCount;

  /// Set once the booking is rejected or cancelled. History stays readable and
  /// new messages are refused with a 422, so the composer is disabled
  /// (API.md §11).
  final bool isLocked;

  bool get hasUnread => unreadCount > 0;

  bool isLastSender(int userId) => lastSenderId == userId;

  Conversation copyWith({
    PublicUser? Function()? otherUser,
    String? lastMessage,
    DateTime? Function()? lastMessageAt,
    int? Function()? lastSenderId,
    int? unreadCount,
    bool? isLocked,
  }) {
    return Conversation(
      id: id,
      bookingId: bookingId,
      rideId: rideId,
      otherUser: otherUser != null ? otherUser() : this.otherUser,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt != null
          ? lastMessageAt()
          : this.lastMessageAt,
      lastSenderId: lastSenderId != null ? lastSenderId() : this.lastSenderId,
      unreadCount: unreadCount ?? this.unreadCount,
      isLocked: isLocked ?? this.isLocked,
    );
  }

  @override
  List<Object?> get props => [
    id,
    bookingId,
    rideId,
    otherUser,
    lastMessage,
    lastMessageAt,
    lastSenderId,
    unreadCount,
    isLocked,
  ];
}

/// Local-only delivery state, so an optimistic bubble can show a spinner or a
/// retry affordance. Never sent to or read from the API.
enum MessageStatus { sending, sent, failed }

/// One message in a thread — `GET /conversations/{id}/messages` (API.md §11).
class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.isMine = false,
    this.readAt,
    this.status = MessageStatus.sent,
  });

  /// Negative for a message that has not reached the server yet — the
  /// optimistic bubble needs a key, and no real id can collide with it.
  final int id;

  final int senderId;
  final String text;
  final DateTime createdAt;

  /// The server's own answer to "did I write this", so the bubble never has to
  /// compare ids.
  final bool isMine;

  /// When the recipient opened the thread past this message.
  final DateTime? readAt;

  final MessageStatus status;

  bool get isRead => readAt != null;
  bool get isPending => status == MessageStatus.sending;
  bool get hasFailed => status == MessageStatus.failed;

  /// An optimistic bubble, shown the instant the user hits send.
  factory ChatMessage.pending({
    required int localId,
    required int senderId,
    required String text,
  }) => ChatMessage(
    id: localId,
    senderId: senderId,
    text: text,
    createdAt: DateTime.now(),
    isMine: true,
    status: MessageStatus.sending,
  );

  ChatMessage copyWith({DateTime? Function()? readAt, MessageStatus? status}) {
    return ChatMessage(
      id: id,
      senderId: senderId,
      text: text,
      createdAt: createdAt,
      isMine: isMine,
      readAt: readAt != null ? readAt() : this.readAt,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [id, senderId, text, createdAt, readAt, status];
}
