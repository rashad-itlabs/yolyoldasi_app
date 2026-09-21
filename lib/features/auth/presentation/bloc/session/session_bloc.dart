import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/error/result.dart';
import '../../../../../core/services/push/push_service.dart';
import '../../../../profile/domain/entities/app_user.dart';
import '../../../../profile/domain/entities/user_enums.dart';
import '../../../../profile/domain/repositories/user_repository.dart';
import '../../../../settings/domain/repositories/settings_repository.dart';
import '../../../domain/entities/auth_session.dart';
import '../../../domain/repositories/auth_repository.dart';

part 'session_event.dart';
part 'session_state.dart';

/// Who is signed in, and everything the router needs to decide where they go.
///
/// Provided above the router so it outlives every screen. It is the only owner
/// of the [AppUser]: other blocs that change the profile hand the result back
/// through [SessionUserUpdated] rather than keeping a second copy.
class SessionBloc extends Bloc<SessionEvent, SessionState> {
  SessionBloc({
    required AuthRepository auth,
    required UserRepository users,
    required SettingsRepository settings,
    PushService push = const InactivePushService(),
  }) : _auth = auth,
       _users = users,
       _settings = settings,
       _push = push,
       super(const SessionState()) {
    on<SessionStarted>(_onStarted);
    on<SessionSignedIn>(_onSignedIn);
    on<SessionRefreshed>(_onRefreshed);
    on<SessionUserUpdated>(_onUserUpdated);
    on<SessionModeRequested>(_onModeRequested);
    on<SessionOnboardingSeen>(_onOnboardingSeen);
    on<SessionSignOutRequested>(_onSignOutRequested);
    on<SessionDeleteAccountRequested>(_onDeleteAccountRequested);
    on<SessionExpired>(_onExpired);

    // API.md §16.2: a 401 means the token was revoked server-side. The
    // interceptor cannot reach into the session itself, so it reports here.
    _expirySubscription = _auth.onSessionExpired.listen(
      (_) => add(const SessionExpired()),
    );
  }

  final AuthRepository _auth;
  final UserRepository _users;
  final SettingsRepository _settings;

  /// Only ever asked for [PushService.currentToken] and told to forget it.
  /// Defaults to the inactive transport so a test — or a build with no push
  /// configured — needs no extra wiring.
  final PushService _push;

  late final StreamSubscription<void> _expirySubscription;

  Future<void> _onStarted(
    SessionStarted event,
    Emitter<SessionState> emit,
  ) async {
    emit(
      state.copyWith(
        status: SessionStatus.booting,
        onboardingSeen: _settings.onboardingSeen,
      ),
    );

    final hasToken = await _auth.restoreSession();
    if (!hasToken) {
      emit(state.signedOut());
      return;
    }
    await _loadProfile(emit);
  }

  Future<void> _onSignedIn(
    SessionSignedIn event,
    Emitter<SessionState> emit,
  ) async {
    emit(
      state.copyWith(
        status: SessionStatus.booting,
        pendingMode: () => event.mode,
        failure: () => null,
      ),
    );
    await _loadProfile(emit);
    await _applyPendingMode(emit);
  }

  Future<void> _onRefreshed(
    SessionRefreshed event,
    Emitter<SessionState> emit,
  ) async {
    if (!_auth.hasSession) return;
    // No `booting` here: a refresh must not throw the user back to the splash
    // screen mid-session. The current profile stays on screen until `/me`
    // answers.
    await _loadProfile(emit, keepCurrentOnFailure: true);
    await _applyPendingMode(emit);
  }

  Future<void> _loadProfile(
    Emitter<SessionState> emit, {
    bool keepCurrentOnFailure = false,
  }) async {
    final result = await _users.me();
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(user: () => value, status: _statusFor(value)));
      case Err(:final failure):
        // 403 is the blocked-account answer (API.md §3); the user stays
        // "signed in" so the blocked screen can explain why.
        if (failure is PermissionFailure) {
          emit(
            state.copyWith(
              status: SessionStatus.blocked,
              failure: () => failure,
            ),
          );
          return;
        }
        // A 401 already went through the interceptor and will arrive as
        // [SessionExpired]; anything else on a live session is transient, so
        // the cached profile is better than bouncing to the login screen.
        if (keepCurrentOnFailure && state.user != null) {
          emit(state.copyWith(failure: () => failure));
          return;
        }
        if (failure is AuthFailure &&
            failure.code == FailureCode.unauthenticated) {
          await _auth.clearSession();
          emit(state.signedOut());
          return;
        }
        emit(state.copyWith(failure: () => failure));
    }
  }

  static SessionStatus _statusFor(AppUser user) =>
      user.isProfileComplete ? SessionStatus.ready : SessionStatus.needsProfile;

  void _onUserUpdated(SessionUserUpdated event, Emitter<SessionState> emit) {
    emit(
      state.copyWith(
        user: () => event.user,
        status: _statusFor(event.user),
        failure: () => null,
      ),
    );
  }

  /// Lands the sign-in pick as soon as the account can take it.
  ///
  /// The choice cannot be applied on the sign-in screen itself: `PUT /me/mode`
  /// needs the profile `/me` has just returned. And it answers 422 for
  /// `driver` on an account with no car (API.md §5) — trading a sign-in for an
  /// error message would be a poor welcome, so the pick is held instead of
  /// dropped. The first vehicle flips `has_driver_profile`, and the `/me` read
  /// that follows it moves the user across by itself. Mode is decided here and
  /// nowhere else; no screen switches it.
  Future<void> _applyPendingMode(Emitter<SessionState> emit) async {
    final wanted = state.pendingMode;
    final user = state.user;
    if (wanted == null || user == null) return;

    // Still out of reach — keep waiting for the first car.
    if (wanted.isDriver && !user.hasDriverProfile) return;

    // Cleared either way: a mode the server refuses must not be retried on
    // every refresh for the rest of the session.
    emit(state.copyWith(pendingMode: () => null));
    if (user.activeMode == wanted) return;

    await _applyMode(wanted, emit);
  }

  /// `PUT /me/mode`.
  Future<void> _applyMode(UserMode mode, Emitter<SessionState> emit) async {
    final user = state.user!;

    // Optimistic: the tab bar should swap immediately. `PUT /me/mode` answers
    // 422 when the account has no driver profile, and the rollback below puts
    // the old mode back if it does.
    emit(state.copyWith(user: () => user.copyWith(activeMode: mode)));

    final result = await _users.setActiveMode(mode);
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(user: () => value));
      case Err(:final failure):
        emit(state.copyWith(user: () => user, failure: () => failure));
    }
  }

  /// The profile tab's mode switch.
  ///
  /// Guarded here rather than at the call site so the rule lives with the
  /// session: `PUT /me/mode` answers 422 for `driver` without a car, and the
  /// screen should send the user to add one instead of showing them an error.
  Future<void> _onModeRequested(
    SessionModeRequested event,
    Emitter<SessionState> emit,
  ) async {
    final user = state.user;
    if (user == null || user.activeMode == event.mode) return;

    if (event.mode.isDriver && !user.hasDriverProfile) {
      emit(
        state.copyWith(
          failure: () => const ValidationFailure(FailureCode.driverProfileRequired),
        ),
      );
      return;
    }

    await _applyMode(event.mode, emit);
  }

  Future<void> _onOnboardingSeen(
    SessionOnboardingSeen event,
    Emitter<SessionState> emit,
  ) async {
    emit(state.copyWith(onboardingSeen: true));
    await _settings.setOnboardingSeen(true);
  }

  Future<void> _onSignOutRequested(
    SessionSignOutRequested event,
    Emitter<SessionState> emit,
  ) async {
    emit(state.copyWith(isWorking: true, failure: () => null));

    // API.md §5: the device token must be released BEFORE the session goes, or
    // this phone keeps receiving the previous account's notifications. The
    // repository takes it as an argument and does nothing without one — which
    // is exactly what used to happen here, so the unregister never ran.
    await _auth.logout(deviceToken: _push.currentToken);
    await _push.clear();

    // The repository clears the local session whatever the API says — a failed
    // logout must never strand the user inside an account they asked to leave.
    await _settings.clearForSignOut();
    emit(state.signedOut());
  }

  Future<void> _onDeleteAccountRequested(
    SessionDeleteAccountRequested event,
    Emitter<SessionState> emit,
  ) async {
    emit(state.copyWith(isWorking: true, failure: () => null));

    final result = await _auth.deleteAccount(deviceToken: _push.currentToken);
    switch (result) {
      case Ok():
        await _push.clear();
        await _settings.clearForSignOut();
        emit(state.signedOut());
      case Err(:final failure):
        // Deletion is irreversible, so a failure leaves the session intact and
        // says so rather than signing the user out on a guess.
        emit(state.copyWith(isWorking: false, failure: () => failure));
    }
  }

  Future<void> _onExpired(
    SessionExpired event,
    Emitter<SessionState> emit,
  ) async {
    if (state.status == SessionStatus.signedOut) return;
    await _auth.clearSession();
    emit(
      state.signedOut().copyWith(
        failure: () => const AuthFailure(FailureCode.unauthenticated),
      ),
    );
  }

  @override
  Future<void> close() {
    _expirySubscription.cancel();
    return super.close();
  }
}
