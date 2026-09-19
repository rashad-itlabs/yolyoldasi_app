part of 'conversations_bloc.dart';

sealed class ConversationsEvent extends Equatable {
  const ConversationsEvent();

  @override
  List<Object?> get props => const [];
}

class ConversationsRequested extends ConversationsEvent {
  const ConversationsRequested({this.refresh = false});

  final bool refresh;

  @override
  List<Object?> get props => [refresh];
}

class ConversationsMoreRequested extends ConversationsEvent {
  const ConversationsMoreRequested();
}

/// Clears one row's unread badge, after the chat screen has told the server.
class ConversationMarkedRead extends ConversationsEvent {
  const ConversationMarkedRead(this.conversationId);

  final int conversationId;

  @override
  List<Object?> get props => [conversationId];
}
