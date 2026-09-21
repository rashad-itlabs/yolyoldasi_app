part of 'app_update_bloc.dart';

sealed class AppUpdateEvent extends Equatable {
  const AppUpdateEvent();

  @override
  List<Object?> get props => const [];
}

/// Ask the server. Fired at launch and again on every resume — a forced
/// update published while the app sat in the background has to catch it on
/// the way back in, not at the next cold start.
final class AppUpdateChecked extends AppUpdateEvent {
  const AppUpdateChecked();
}

/// "Sonra" on the optional prompt. Remembered per release, so the next one is
/// free to ask again.
final class AppUpdateDismissed extends AppUpdateEvent {
  const AppUpdateDismissed();
}
