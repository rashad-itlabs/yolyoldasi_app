part of 'chat_bloc.dart';

class ChatState extends Equatable {
  const ChatState({
    required this.conversationId,
    this.status = DataStatus.initial,
    this.page = const Paginated<ChatMessage>.empty(),
    this.conversation,
    this.draft = '',
    this.sendStatus = ActionStatus.idle,
    this.isLoadingMore = false,
    this.failure,
  });

  final int conversationId;
  final DataStatus status;

  /// Newest first, exactly as the API returns it.
  final Paginated<ChatMessage> page;

  /// The thread's own row, which carries the counterpart's profile and the
  /// lock flag. The API has no `GET /conversations/{id}`, so it is picked out
  /// of the list — `null` until that read lands, or if the thread is past the
  /// first page of it.
  final Conversation? conversation;

  final String draft;
  final ActionStatus sendStatus;
  final bool isLoadingMore;

  final Failure? failure;

  /// A rejected or cancelled booking locks the thread: history stays readable
  /// and `POST` answers 422 (API.md §11).
  bool get isLocked => conversation?.isLocked ?? false;

  int? get bookingId => conversation?.bookingId;

  /// Oldest first — what the chat list renders, since API.md §11 asks the
  /// client to reverse the page.
  List<ChatMessage> get messages => page.items.reversed.toList(growable: false);

  /// Optimistic bubbles the server has not confirmed yet.
  List<ChatMessage> get pending =>
      page.items.where((m) => m.isPending || m.hasFailed).toList();

  bool get isEmpty => status.isSuccess && page.isEmpty;
  bool get hasOlder => page.hasMore;

  bool get canSend =>
      !isLocked &&
      draft.trim().isNotEmpty &&
      draft.length <= AppRules.maxMessageLength &&
      !sendStatus.isInProgress;

  int get remainingCharacters => AppRules.maxMessageLength - draft.length;

  ChatState copyWith({
    DataStatus? status,
    Paginated<ChatMessage>? page,
    Conversation? Function()? conversation,
    String? draft,
    ActionStatus? sendStatus,
    bool? isLoadingMore,
    Failure? Function()? failure,
  }) {
    return ChatState(
      conversationId: conversationId,
      status: status ?? this.status,
      page: page ?? this.page,
      conversation: conversation != null ? conversation() : this.conversation,
      draft: draft ?? this.draft,
      sendStatus: sendStatus ?? this.sendStatus,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [
    conversationId,
    status,
    page,
    conversation,
    draft,
    sendStatus,
    isLoadingMore,
    failure,
  ];
}
