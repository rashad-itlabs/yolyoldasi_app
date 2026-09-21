part of 'session_bloc.dart';

sealed class SessionEvent extends Equatable {
  const SessionEvent();

  @override
  List<Object?> get props => const [];
}

/// Boot: restore the stored token and, if there is one, load `/me`.
class SessionStarted extends SessionEvent {
  const SessionStarted();
}

/// A session was established and its token saved. This triggers the `/me` read
/// that fills in the rest of the profile.
class SessionSignedIn extends SessionEvent {
  const SessionSignedIn(this.session, {this.mode});

  final AuthSession session;

  /// The side of the app chosen on the sign-in screen — the only place it is
  /// chosen — or `null` to keep whatever `active_mode` the account already has.
  final UserMode? mode;

  @override
  List<Object?> get props => [session, mode];
}

/// Re-reads `/me`. Fired after the app resumes and after any change that the
/// server may have derived (a first vehicle flipping `has_driver_profile`).
class SessionRefreshed extends SessionEvent {
  const SessionRefreshed();
}

/// Adopts a user another bloc just persisted, so the session does not have to
/// re-read `/me` after every profile edit.
class SessionUserUpdated extends SessionEvent {
  const SessionUserUpdated(this.user);

  final AppUser user;

  @override
  List<Object?> get props => [user];
}

/// The onboarding carousel was dismissed. Device-local, but the router reads it.
/// The user asked to switch between passenger and driver from the profile tab.
///
/// The mode used to be fixed at sign-in, changeable only by signing out and
/// doing the OTP again. In practice the same person drives to their home
/// district on Friday and rides back on Monday, so that lock halved what every
/// account was worth — and it hid the driver half of the app from every
/// passenger who owned a car, which is the cheapest source of drivers there is.
class SessionModeRequested extends SessionEvent {
  const SessionModeRequested(this.mode);

  final UserMode mode;

  @override
  List<Object?> get props => [mode];
}

class SessionOnboardingSeen extends SessionEvent {
  const SessionOnboardingSeen();
}

/// User-initiated sign-out: `POST /auth/logout`.
class SessionSignOutRequested extends SessionEvent {
  const SessionSignOutRequested();
}

/// `DELETE /auth/account` — irreversible, and confirmed before it is fired.
class SessionDeleteAccountRequested extends SessionEvent {
  const SessionDeleteAccountRequested();
}

/// The API rejected the stored token (API.md §16.2). Raised from the
/// interceptor's stream, never by a screen.
class SessionExpired extends SessionEvent {
  const SessionExpired();
}
