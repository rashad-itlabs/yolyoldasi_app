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
/// changed them — the app resuming, a thread being opened, a booking decided.
class BadgesBloc extends Bloc<BadgesEvent, BadgesState> {
  BadgesBloc({
    required ChatRepository chat,
    required NotificationRepository notifications,
  }) : _chat = chat,
       _notifications = notifications,
       super(const BadgesState()) {
    on<BadgesRefreshed>(_onRefreshed, transformer: droppable());
    on<BadgesCleared>(_onCleared);
    on<MessageBadgeAdjusted>(_onMessageBadgeAdjusted);
    on<NotificationBadgeAdjusted>(_onNotificationBadgeAdjusted);
  }

  final ChatRepository _chat;
  final NotificationRepository _notifications;

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

  void _onMessageBadgeAdjusted(
    MessageBadgeAdjusted event,
    Emitter<BadgesState> emit,
  ) {
    emit(state.copyWith(unreadMessages: event.total));
  }

  void _onNotificationBadgeAdjusted(
    NotificationBadgeAdjusted event,
    Emitter<BadgesState> emit,
  ) {
    emit(state.copyWith(unreadNotifications: event.total));
  }
}
