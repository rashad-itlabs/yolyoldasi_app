part of 'chat_bloc.dart';

sealed class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => const [];
}

/// Loads the thread and starts polling. Also marks it read.
class ChatStarted extends ChatEvent {
  const ChatStarted();
}

/// Pages further back through the history; the API returns 50 at a time,
/// newest first.
class ChatOlderRequested extends ChatEvent {
  const ChatOlderRequested();
}

class ChatDraftChanged extends ChatEvent {
  const ChatDraftChanged(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

/// `POST /conversations/{id}/messages`.
class ChatMessageSent extends ChatEvent {
  const ChatMessageSent({required this.senderId});

  /// Needed only to build the optimistic bubble; the server knows who is
  /// writing from the token.
  final int senderId;

  @override
  List<Object?> get props => [senderId];
}

/// Fired by the poll timer. Never shows a spinner.
class ChatPollTicked extends ChatEvent {
  const ChatPollTicked();
}

class ChatFailureCleared extends ChatEvent {
  const ChatFailureCleared();
}
