part of 'badges_bloc.dart';

sealed class BadgesEvent extends Equatable {
  const BadgesEvent();

  @override
  List<Object?> get props => const [];
}

/// Re-reads both counters. Fired on sign-in, on app resume, when a push
/// arrives, and after any action that could change them.
///
/// There is deliberately no event that sets or bumps a counter locally. The
/// one there was took a total, and the push handler passed it `1` meaning
/// "one more" — so every push reset the badge to 1. A local guess is also
/// wrong more often than it looks: a chat message is both an unread message
/// and an unread notification, and the foreground watcher reports a thread
/// once however many messages arrived in it. The server's count is always
/// right, and it is two small reads away.
class BadgesRefreshed extends BadgesEvent {
  const BadgesRefreshed();
}

/// Zeroes both, on sign-out.
class BadgesCleared extends BadgesEvent {
  const BadgesCleared();
}
