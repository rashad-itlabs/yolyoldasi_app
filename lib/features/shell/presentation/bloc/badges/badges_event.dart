part of 'badges_bloc.dart';

sealed class BadgesEvent extends Equatable {
  const BadgesEvent();

  @override
  List<Object?> get props => const [];
}

/// Re-reads both counters. Fired on sign-in, on app resume, and after any
/// action that could change them.
class BadgesRefreshed extends BadgesEvent {
  const BadgesRefreshed();
}

/// Zeroes both, on sign-out.
class BadgesCleared extends BadgesEvent {
  const BadgesCleared();
}

/// Sets the message badge directly, so opening a thread updates the navigation
/// bar without a round trip.
class MessageBadgeAdjusted extends BadgesEvent {
  const MessageBadgeAdjusted(this.total);

  final int total;

  @override
  List<Object?> get props => [total];
}

class NotificationBadgeAdjusted extends BadgesEvent {
  const NotificationBadgeAdjusted(this.total);

  final int total;

  @override
  List<Object?> get props => [total];
}
