part of 'notification_preferences_bloc.dart';

/// The five switches, each knowing how to apply itself.
///
/// [pushEnabled] is the master: API.md §4 says it sits above the other four,
/// so turning it off mutes everything without clearing the individual choices.
enum NotificationChannel {
  pushEnabled,
  bookings,
  messages,
  reminders,
  marketing;

  bool readFrom(NotificationPreferences prefs) => switch (this) {
    NotificationChannel.pushEnabled => prefs.pushEnabled,
    NotificationChannel.bookings => prefs.bookings,
    NotificationChannel.messages => prefs.messages,
    NotificationChannel.reminders => prefs.reminders,
    NotificationChannel.marketing => prefs.marketing,
  };

  NotificationPreferences applyTo(NotificationPreferences prefs, bool value) =>
      switch (this) {
        NotificationChannel.pushEnabled => prefs.copyWith(pushEnabled: value),
        NotificationChannel.bookings => prefs.copyWith(bookings: value),
        NotificationChannel.messages => prefs.copyWith(messages: value),
        NotificationChannel.reminders => prefs.copyWith(reminders: value),
        NotificationChannel.marketing => prefs.copyWith(marketing: value),
      };
}

sealed class NotificationPreferencesEvent extends Equatable {
  const NotificationPreferencesEvent();

  @override
  List<Object?> get props => const [];
}

class NotificationPreferencesRequested extends NotificationPreferencesEvent {
  const NotificationPreferencesRequested({this.seed});

  /// The copy already on the signed-in profile, so the screen renders before
  /// `GET /me/notification-preferences` answers.
  final NotificationPreferences? seed;

  @override
  List<Object?> get props => [seed];
}

class NotificationPreferenceToggled extends NotificationPreferencesEvent {
  const NotificationPreferenceToggled(this.channel, this.value);

  final NotificationChannel channel;
  final bool value;

  @override
  List<Object?> get props => [channel, value];
}
