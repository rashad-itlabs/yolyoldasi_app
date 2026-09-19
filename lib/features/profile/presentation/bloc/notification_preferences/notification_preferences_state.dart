part of 'notification_preferences_bloc.dart';

class NotificationPreferencesState extends Equatable {
  const NotificationPreferencesState({
    this.status = DataStatus.initial,
    this.preferences,
    this.saveStatus = ActionStatus.idle,
    this.failure,
  });

  final DataStatus status;
  final NotificationPreferences? preferences;
  final ActionStatus saveStatus;
  final Failure? failure;

  NotificationPreferences get current =>
      preferences ?? NotificationPreferences.defaults;

  bool valueOf(NotificationChannel channel) => channel.readFrom(current);

  /// Whether a per-channel switch should be greyed out — the master is off, so
  /// nothing arrives regardless of the individual settings.
  bool isMutedBy(NotificationChannel channel) =>
      channel != NotificationChannel.pushEnabled && !current.pushEnabled;

  NotificationPreferencesState copyWith({
    DataStatus? status,
    NotificationPreferences? preferences,
    ActionStatus? saveStatus,
    Failure? Function()? failure,
  }) {
    return NotificationPreferencesState(
      status: status ?? this.status,
      preferences: preferences ?? this.preferences,
      saveStatus: saveStatus ?? this.saveStatus,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [status, preferences, saveStatus, failure];
}
