import 'package:equatable/equatable.dart';

import '../../../profile/domain/entities/user_enums.dart';

/// A live API session: the Sanctum token plus a thin summary of who it belongs
/// to.
///
/// `POST /auth/phone/verify` issues this (API.md §3). The summary is only what
/// that response carries — enough to route the user while `GET /me` fetches the
/// full profile, which `SessionBloc` owns from then on.
class AuthSession extends Equatable {
  const AuthSession({
    required this.token,
    required this.userId,
    this.fullName = '',
    this.phone = '',
    this.activeMode = UserMode.passenger,
    this.hasDriverProfile = false,
    this.isNewUser = false,
  });

  /// The Sanctum token. Non-expiring for `device: "app"`.
  final String token;

  final int userId;
  final String fullName;
  final String phone;
  final UserMode activeMode;
  final bool hasDriverProfile;

  /// Whether this verify created the account rather than opening an existing
  /// one (API.md §3). The difference between a sign-in and an acquisition, and
  /// the funnel cannot be read without it.
  final bool isNewUser;

  @override
  List<Object?> get props => [
    token,
    userId,
    fullName,
    phone,
    activeMode,
    hasDriverProfile,
    isNewUser,
  ];
}
