part of 'session_bloc.dart';

/// Where the user stands right now — the single input to the router's redirect.
enum SessionStatus {
  /// Still restoring the token and reading `/me`; the splash is showing.
  booting,

  signedOut,

  /// Signed in, but the profile has no name yet. `POST /auth/firebase` makes
  /// `full_name` optional, so a fresh account lands here.
  needsProfile,

  ready,

  /// The API answered 403 "hesab bloklanıb" (API.md §3).
  blocked,
}

class SessionState extends Equatable {
  const SessionState({
    this.status = SessionStatus.booting,
    this.user,
    this.pendingMode,
    this.onboardingSeen = false,
    this.isWorking = false,
    this.failure,
  });

  final SessionStatus status;

  /// The full `/me` profile. Present for every status except [signedOut] and,
  /// usually, [blocked] — a blocked account never gets as far as `/me`.
  final AppUser? user;

  /// The side of the app picked on the sign-in screen, still waiting for an
  /// account that can take it. Only `driver` ever lingers here: `PUT /me/mode`
  /// refuses it until a first car exists (API.md §5), so the choice is held
  /// rather than dropped. See [SessionBloc._applyPendingMode].
  final UserMode? pendingMode;

  final bool onboardingSeen;

  /// A sign-out or account deletion is in flight.
  final bool isWorking;

  /// Set when signing out or deleting failed. Sign-in failures belong to
  /// [PhoneSignInBloc], not here.
  final Failure? failure;

  bool get isSignedIn => user != null;
  bool get isReady => status == SessionStatus.ready;
  bool get isBooting => status == SessionStatus.booting;

  int? get userId => user?.id;
  UserMode get activeMode => user?.activeMode ?? UserMode.passenger;
  bool get isDriverMode => activeMode.isDriver;
  bool get hasDriverProfile => user?.hasDriverProfile ?? false;
  String get languageCode => user?.languageCode ?? 'az';

  SessionState copyWith({
    SessionStatus? status,
    AppUser? Function()? user,
    UserMode? Function()? pendingMode,
    bool? onboardingSeen,
    bool? isWorking,
    Failure? Function()? failure,
  }) {
    return SessionState(
      status: status ?? this.status,
      user: user != null ? user() : this.user,
      pendingMode: pendingMode != null ? pendingMode() : this.pendingMode,
      onboardingSeen: onboardingSeen ?? this.onboardingSeen,
      isWorking: isWorking ?? this.isWorking,
      failure: failure != null ? failure() : this.failure,
    );
  }

  /// The signed-out state, keeping the device-scoped bits that survive it.
  SessionState signedOut() => SessionState(
    status: SessionStatus.signedOut,
    onboardingSeen: onboardingSeen,
  );

  @override
  List<Object?> get props => [
    status,
    user,
    pendingMode,
    onboardingSeen,
    isWorking,
    failure,
  ];
}
