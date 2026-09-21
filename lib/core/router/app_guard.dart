import '../../features/auth/presentation/bloc/session/session_bloc.dart';
import 'app_routes.dart';

/// Routes that are only reachable while signed out.
const _authRoutes = {Routes.splash, Routes.onboarding, Routes.login};

/// Where a given location is allowed to resolve, and nothing else.
///
/// Lifted out of `buildRouter` so it can be read — and tested — on its own.
/// It is the only thing standing between an unsupported build and the rest of
/// the app, and a guard that can only be exercised by pumping the whole widget
/// tree is a guard nobody checks.
abstract final class AppGuard {
  /// Null means "stay here"; anything else is where to go instead.
  ///
  /// [updateBlocks] comes ahead of [session] on purpose: a build the server
  /// has stopped supporting must not reach the sign-in screen, let alone the
  /// app behind it.
  static String? redirect({
    required SessionState session,
    required bool updateBlocks,
    required String location,
  }) {
    if (updateBlocks) {
      return location == Routes.updateRequired ? null : Routes.updateRequired;
    }

    switch (session.status) {
      case SessionStatus.booting:
        return location == Routes.splash ? null : Routes.splash;

      case SessionStatus.signedOut:
        if (!session.onboardingSeen) {
          return location == Routes.onboarding ? null : Routes.onboarding;
        }
        return location == Routes.login ? null : Routes.login;

      case SessionStatus.needsProfile:
        return location == Routes.profileSetup ? null : Routes.profileSetup;

      case SessionStatus.blocked:
        return location == Routes.blocked ? null : Routes.blocked;

      case SessionStatus.ready:
        // The gates the user has already passed: none of them is a place to
        // be once there is an account to come back to.
        if (_authRoutes.contains(location) ||
            location == Routes.profileSetup ||
            location == Routes.blocked ||
            location == Routes.updateRequired) {
          return Routes.home;
        }
        return null;
    }
  }
}
