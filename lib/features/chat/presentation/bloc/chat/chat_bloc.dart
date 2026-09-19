import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/data_status.dart';
import '../../../../../core/config/app_config.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/result.dart';
import '../../../../../core/network/api_envelope.dart';
import '../../../domain/entities/conversation.dart';
import '../../../domain/repositories/chat_repository.dart';

part 'chat_event.dart';
part 'chat_state.dart';

/// One thread — `GET|POST /conversations/{id}/messages` (API.md §11).
///
/// The API has no realtime transport, so the thread is re-read on a timer
/// while the screen is open. [ChatPollTicked] is what the timer fires; it is a
/// quiet reload that never shows a spinner, so an incoming message simply
/// appears.
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc({required ChatRepository chat, required int conversationId})
    : _chat = chat,
      super(ChatState(conversationId: conversationId)) {
    on<ChatStarted>(_onStarted, transformer: restartable());
    on<ChatOlderRequested>(_onOlderRequested, transformer: droppable());
    on<ChatDraftChanged>(_onDraftChanged);
    on<ChatMessageSent>(_onMessageSent, transformer: sequential());
    on<ChatPollTicked>(_onPollTicked, transformer: droppable());
    on<ChatFailureCleared>(_onFailureCleared);
  }

  final ChatRepository _chat;
  Timer? _poll;

  /// Local ids for optimistic bubbles. Negative so they can never collide with
  /// a server id.
  int _nextLocalId = -1;

  Future<void> _onStarted(ChatStarted event, Emitter<ChatState> emit) async {
    emit(state.copyWith(status: DataStatus.loading, failure: () => null));

    // The messages and the thread's own row are fetched together: the API has
    // no `GET /conversations/{id}`, so the header and the lock flag have to
    // come out of the list.
    final results = await Future.wait([
      _chat.messages(state.conversationId),
      _chat.conversations(),
    ]);
    final messages = results[0] as Result<Paginated<ChatMessage>>;
    final conversations = results[1] as Result<Paginated<Conversation>>;

    switch (messages) {
      case Ok(:final value):
        emit(
          state.copyWith(
            status: DataStatus.success,
            page: value,
            conversation: () => _find(conversations),
          ),
        );
        // Opening the thread clears its badge and stamps `read_at` on the
        // other side's messages (API.md §11).
        unawaited(_chat.markRead(state.conversationId));
        _startPolling();
      case Err(:final failure):
        emit(
          state.copyWith(status: DataStatus.failure, failure: () => failure),
        );
    }
  }

  Conversation? _find(Result<Paginated<Conversation>> result) {
    final page = result.valueOrNull;
    if (page == null) return null;
    for (final conversation in page.items) {
      if (conversation.id == state.conversationId) return conversation;
    }
    return null;
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(
      AppConfig.chatPollInterval,
      (_) => add(const ChatPollTicked()),
    );
  }

  Future<void> _onPollTicked(
    ChatPollTicked event,
    Emitter<ChatState> emit,
  ) async {
    if (state.status.isBusy || state.sendStatus.isInProgress) return;

    final result = await _chat.messages(state.conversationId);
    if (result case Ok(:final value)) {
      // Only the first page is polled, so anything already paged in is kept by
      // merging rather than replacing.
      final merged = _merge(value.items, state.pending);
      if (merged.length == state.page.items.length &&
          merged.isNotEmpty &&
          merged.first.id == state.page.items.firstOrNull?.id) {
        return; // Nothing new — skip the rebuild.
      }
      emit(state.copyWith(page: state.page.replacingItems(merged)));
      unawaited(_chat.markRead(state.conversationId));
    }
  }

  /// Keeps optimistic bubbles that the server has not echoed back yet at the
  /// front of the list, so a message never flickers out and back in.
  List<ChatMessage> _merge(
    List<ChatMessage> fromServer,
    List<ChatMessage> pending,
  ) {
    if (pending.isEmpty) return fromServer;
    final texts = fromServer.map((m) => m.text).toSet();
    final stillPending = pending
        .where((m) => !texts.contains(m.text))
        .toList(growable: false);
    return [...stillPending, ...fromServer];
  }

  Future<void> _onOlderRequested(
    ChatOlderRequested event,
    Emitter<ChatState> emit,
  ) async {
    if (!state.page.hasMore || state.isLoadingMore) return;

    emit(state.copyWith(isLoadingMore: true));

    final result = await _chat.messages(
      state.conversationId,
      page: state.page.nextPage,
    );
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(isLoadingMore: false, page: state.page.concat(value)),
        );
      case Err(:final failure):
        emit(state.copyWith(isLoadingMore: false, failure: () => failure));
    }
  }

  void _onDraftChanged(ChatDraftChanged event, Emitter<ChatState> emit) {
    emit(state.copyWith(draft: event.text, failure: () => null));
  }

  Future<void> _onMessageSent(
    ChatMessageSent event,
    Emitter<ChatState> emit,
  ) async {
    final text = state.draft.trim();
    if (text.isEmpty || text.length > AppRules.maxMessageLength) return;
    if (state.isLocked) return;

    final optimistic = ChatMessage.pending(
      localId: _nextLocalId--,
      senderId: event.senderId,
      text: text,
    );

    emit(
      state.copyWith(
        draft: '',
        sendStatus: ActionStatus.inProgress,
        page: state.page.replacingItems([optimistic, ...state.page.items]),
        failure: () => null,
      ),
    );

    final result = await _chat.send(state.conversationId, text);
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            sendStatus: ActionStatus.success,
            page: state.page.replacingItems([
              for (final message in state.page.items)
                if (message.id == optimistic.id) value else message,
            ]),
          ),
        );
      case Err(:final failure):
        // The bubble stays, marked failed, so the text is not lost — a 422
        // here means the booking was cancelled and the thread locked while the
        // message was being typed.
        emit(
          state.copyWith(
            sendStatus: ActionStatus.failure,
            draft: text,
            page: state.page.replacingItems([
              for (final message in state.page.items)
                if (message.id == optimistic.id)
                  message.copyWith(status: MessageStatus.failed)
                else
                  message,
            ]),
            failure: () => failure,
          ),
        );
    }
  }

  void _onFailureCleared(ChatFailureCleared event, Emitter<ChatState> emit) {
    emit(state.copyWith(failure: () => null, sendStatus: ActionStatus.idle));
  }

  @override
  Future<void> close() {
    _poll?.cancel();
    return super.close();
  }
}
