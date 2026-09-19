import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/data_status.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/result.dart';
import '../../../../../core/network/api_envelope.dart';
import '../../../domain/entities/conversation.dart';
import '../../../domain/repositories/chat_repository.dart';

part 'conversations_event.dart';
part 'conversations_state.dart';

/// `GET /conversations` — the message list.
class ConversationsBloc extends Bloc<ConversationsEvent, ConversationsState> {
  ConversationsBloc({required ChatRepository chat})
    : _chat = chat,
      super(const ConversationsState()) {
    on<ConversationsRequested>(_onRequested, transformer: restartable());
    on<ConversationsMoreRequested>(_onMoreRequested, transformer: droppable());
    on<ConversationMarkedRead>(_onMarkedRead);
  }

  final ChatRepository _chat;

  Future<void> _onRequested(
    ConversationsRequested event,
    Emitter<ConversationsState> emit,
  ) async {
    emit(
      state.copyWith(
        status: state.page.isNotEmpty && event.refresh
            ? DataStatus.refreshing
            : DataStatus.loading,
        failure: () => null,
      ),
    );

    final result = await _chat.conversations();
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(status: DataStatus.success, page: value));
      case Err(:final failure):
        emit(
          state.copyWith(status: DataStatus.failure, failure: () => failure),
        );
    }
  }

  Future<void> _onMoreRequested(
    ConversationsMoreRequested event,
    Emitter<ConversationsState> emit,
  ) async {
    if (!state.page.hasMore || state.isLoadingMore || state.status.isBusy) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true));

    final result = await _chat.conversations(page: state.page.nextPage);
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(isLoadingMore: false, page: state.page.concat(value)),
        );
      case Err(:final failure):
        emit(state.copyWith(isLoadingMore: false, failure: () => failure));
    }
  }

  /// Zeroes a row's badge the moment its thread is opened, without waiting for
  /// the list to be re-read. The chat screen has already told the server.
  void _onMarkedRead(
    ConversationMarkedRead event,
    Emitter<ConversationsState> emit,
  ) {
    emit(
      state.copyWith(
        page: state.page.replacingItems([
          for (final conversation in state.page.items)
            if (conversation.id == event.conversationId)
              conversation.copyWith(unreadCount: 0)
            else
              conversation,
        ]),
      ),
    );
  }
}
