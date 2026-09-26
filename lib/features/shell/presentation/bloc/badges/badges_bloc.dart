import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';

import '../../../../chat/domain/repositories/chat_repository.dart';
import '../../../../notifications/domain/repositories/notification_repository.dart';

part 'badges_event.dart';
part 'badges_state.dart';

/// The two counters in the navigation bar: unread messages and unread
/// notifications.
///
/// `GET /conversations/unread-count` and `GET /notifications/unread-count`
/// exist precisely for this (API.md §11 and §13). They are read together
/// because the shell shows both, and re-read whenever something could have
/// changed them — the app resuming, a push arriving, a booking decided.
///
/// Reads are the one change this bloc hears about by itself. A thread marked
/// read ([ChatRepository.threadsRead]) lowers *both* counters, because the
/// server marks that thread's `newMessage` notifications read in the same
/// call; a notification marked read ([NotificationRepository.changes]) lowers
/// the bell. Both are announced by the repository once the write has landed,
/// which is the only moment a re-read can see it. Listening here, rather than
/// having the chat screen tell this bloc, covers every way into a thread — the
/// list, a notification row, a push, a booking's "message" button — and still
/// works when the user backs out before the call returns. A failed write
/// announces nothing, so it cannot clear a badge the server still counts.
class BadgesBloc extends Bloc<BadgesEvent, BadgesState> {
  BadgesBloc({
    required ChatRepository chat,
    required NotificationRepository notifications,
  }) : _chat = chat,
       _notifications = notifications,
       super(const BadgesState()) {
    // Restartable, not droppable: every refresh is asked for because something
    // just changed on the server, so the newest request is the one that knows
    // about it. Dropping it in favour of one already in flight — begun, say,
    // by a push tap a moment before the thread was marked read — kept the
    // stale answer and threw away the fresh one.
    on<BadgesRefreshed>(_onRefreshed, transformer: restartable());
    on<BadgesCleared>(_onCleared);

    _threadsRead = chat.threadsRead.listen((_) => add(const BadgesRefreshed()));
    _notificationChanges = notifications.changes.listen(
      (_) => add(const BadgesRefreshed()),
    );
  }

  final ChatRepository _chat;
  final NotificationRepository _notifications;
  late final StreamSubscription<int> _threadsRead;
  late final StreamSubscription<void> _notificationChanges;

  @override
  Future<void> close() async {
    await _threadsRead.cancel();
    await _notificationChanges.cancel();
    return super.close();
  }

  Future<void> _onRefreshed(
    BadgesRefreshed event,
    Emitter<BadgesState> emit,
  ) async {
    final results = await Future.wait([
      _chat.unreadTotal(),
      _notifications.unreadTotal(),
    ]);

    // A badge is decoration: a failed count leaves the previous number alone
    // rather than showing zero, which would read as "all caught up".
    emit(
      state.copyWith(
        unreadMessages: results[0].valueOrNull,
        unreadNotifications: results[1].valueOrNull,
      ),
    );
  }

  void _onCleared(BadgesCleared event, Emitter<BadgesState> emit) {
    emit(const BadgesState());
  }
}
