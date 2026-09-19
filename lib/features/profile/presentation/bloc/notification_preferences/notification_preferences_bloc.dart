import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/data_status.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/result.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/repositories/user_repository.dart';

part 'notification_preferences_event.dart';
part 'notification_preferences_state.dart';

/// The five switches on the settings screen — API.md §4.
///
/// Every toggle writes straight through: `PUT` accepts any subset, the whole
/// object is small, and a settings screen with a separate "save" button would
/// be a worse trade than an optimistic switch that rolls back.
class NotificationPreferencesBloc
    extends Bloc<NotificationPreferencesEvent, NotificationPreferencesState> {
  NotificationPreferencesBloc({required UserRepository users})
    : _users = users,
      super(const NotificationPreferencesState()) {
    on<NotificationPreferencesRequested>(_onRequested);
    on<NotificationPreferenceToggled>(_onToggled);
  }

  final UserRepository _users;

  Future<void> _onRequested(
    NotificationPreferencesRequested event,
    Emitter<NotificationPreferencesState> emit,
  ) async {
    // The signed-in profile already carries the preferences, so the settings
    // screen can render immediately and only re-read to confirm.
    final seeded = event.seed;
    if (seeded != null && state.status.isInitial) {
      emit(state.copyWith(status: DataStatus.success, preferences: seeded));
    }
    if (state.status.isBusy) return;

    emit(
      state.copyWith(
        status: state.status.isSuccess
            ? DataStatus.refreshing
            : DataStatus.loading,
        failure: () => null,
      ),
    );

    final result = await _users.notificationPreferences();
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(status: DataStatus.success, preferences: value));
      case Err(:final failure):
        emit(
          state.copyWith(
            status: state.preferences == null
                ? DataStatus.failure
                : DataStatus.success,
            failure: () => failure,
          ),
        );
    }
  }

  Future<void> _onToggled(
    NotificationPreferenceToggled event,
    Emitter<NotificationPreferencesState> emit,
  ) async {
    final current = state.preferences;
    if (current == null || state.saveStatus.isInProgress) return;

    final next = event.channel.applyTo(current, event.value);
    if (next == current) return;

    emit(
      state.copyWith(
        preferences: next,
        saveStatus: ActionStatus.inProgress,
        failure: () => null,
      ),
    );

    final result = await _users.saveNotificationPreferences(next);
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(preferences: value, saveStatus: ActionStatus.success),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            preferences: current,
            saveStatus: ActionStatus.failure,
            failure: () => failure,
          ),
        );
    }
  }
}
