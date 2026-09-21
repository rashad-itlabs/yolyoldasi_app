import '../../features/auth/presentation/bloc/session/session_bloc.dart';
import 'app_routes.dart';

/// Routes that are only reachable while signed out.
const _authRoutes = {Routes.splash, Routes.onboarding, Routes.login};

/// What a signed-out visitor is allowed to look at.
///
/// This is the single biggest hole in the funnel closed: until now the first
/// screen after onboarding asked for a phone number, and a visitor had to hand
/// one over before seeing that a single ride existed. Nobody gives their number
/// to an empty room. These four endpoints are open on the server too
/// (API.md §18), so the screens work with no token at all.
///
/// Everything that *writes* — booking, messaging, publishing, posting a
/// request — still needs an account, and each of those buttons sends the
/// visitor to sign in at the moment they reach for it.
const _guestRoutes = {
  Routes.home,
  Routes.searchResults,
  Routes.login,
};

/// Whether a signed-out visitor may stay on [location].
///
/// Prefix matching for the two detail screens: their paths carry an id, so an
/// exact-set test would never hit them.
bool _isGuestRoute(String location) =>
    _guestRoutes.contains(location) ||
    location.startsWith('/ride/') ||
    location.startsWith('/user/');

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
        // Browsing is the default state, not sign-in.
        //
        // The destination here is `home`, and that is the whole point: `/splash`
        // is not a guest route, so sending the unmatched case to `login` put
        // every launch back on the phone-number screen and made the open door
        // reachable only by noticing one button on the onboarding screen —
        // which an existing install never sees again.
        //
        // Sign-in is somewhere the visitor goes, not somewhere they are put:
        // `login` is in [_guestRoutes], and every button that needs an account
        // pushes it at the moment it is needed.
        return _isGuestRoute(location) ? null : Routes.home;

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
