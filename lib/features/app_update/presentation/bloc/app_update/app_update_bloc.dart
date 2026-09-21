import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/error/result.dart';
import '../../../../../core/services/app_version_info.dart';
import '../../../../settings/domain/repositories/settings_repository.dart';
import '../../../domain/entities/app_update.dart';
import '../../../domain/repositories/app_update_repository.dart';

part 'app_update_event.dart';
part 'app_update_state.dart';

/// Whether this build may still be used, and what to say if not.
///
/// Provided above the router, like [SessionBloc], because the router's guard
/// reads it: a forced update outranks every other destination, including the
/// sign-in screen.
///
/// One rule shapes the whole class — **a check that does not succeed changes
/// nothing**. The server being unreachable is not evidence that the app is out
/// of date, and treating it as such would take the app down for every user
/// every time the API hiccups. So a failure leaves the previous state alone
/// and the app open.
class AppUpdateBloc extends Bloc<AppUpdateEvent, AppUpdateState> {
  AppUpdateBloc({
    required AppUpdateRepository updates,
    required SettingsRepository settings,
    AppVersionInfo installed = AppVersionInfo.unknown,
  }) : _updates = updates,
       _settings = settings,
       super(
         AppUpdateState(
           installed: installed,
           dismissedVersion: settings.dismissedUpdateVersion,
         ),
       ) {
    // Droppable: the launch check and a resume landing on top of it are the
    // same question, and the first answer is as good as the second.
    on<AppUpdateChecked>(_onChecked, transformer: droppable());
    on<AppUpdateDismissed>(_onDismissed);
  }

  final AppUpdateRepository _updates;
  final SettingsRepository _settings;

  Future<void> _onChecked(
    AppUpdateChecked event,
    Emitter<AppUpdateState> emit,
  ) async {
    final result = await _updates.check();

    // Deliberately not `fold`: there is nothing to do on the error branch.
    // No error state, no retry, no message — the user is not waiting on this
    // and has no part to play in it.
    if (result case Ok(:final value)) {
      emit(state.copyWith(update: value));
    }
  }

  Future<void> _onDismissed(
    AppUpdateDismissed event,
    Emitter<AppUpdateState> emit,
  ) async {
    final version = state.update.latestVersion;
    if (version == null) return;

    emit(state.copyWith(dismissedVersion: () => version));
    await _settings.setDismissedUpdateVersion(version);
  }
}
