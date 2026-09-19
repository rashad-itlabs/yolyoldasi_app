part of 'badges_bloc.dart';

class BadgesState extends Equatable {
  const BadgesState({this.unreadMessages = 0, this.unreadNotifications = 0});

  final int unreadMessages;
  final int unreadNotifications;

  bool get hasUnreadMessages => unreadMessages > 0;
  bool get hasUnreadNotifications => unreadNotifications > 0;

  /// Badges stop counting past this and render as "99+", which is as much as
  /// the pill can hold.
  static const int displayCap = 99;

  String? get messageBadge => _label(unreadMessages);
  String? get notificationBadge => _label(unreadNotifications);

  static String? _label(int count) {
    if (count <= 0) return null;
    return count > displayCap ? '$displayCap+' : '$count';
  }

  BadgesState copyWith({int? unreadMessages, int? unreadNotifications}) {
    return BadgesState(
      unreadMessages: unreadMessages ?? this.unreadMessages,
      unreadNotifications: unreadNotifications ?? this.unreadNotifications,
    );
  }

  @override
  List<Object?> get props => [unreadMessages, unreadNotifications];
}
