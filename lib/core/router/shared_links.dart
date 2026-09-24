import '../../features/auth/presentation/bloc/session/session_bloc.dart';
import 'app_guard.dart';
import 'app_routes.dart';

/// Web links that open inside the app, and where each one lands.
///
/// A listing's `share_url` is `https://yolyoldasi.az/r/{id}` (API.md §21) —
/// the page the website serves to someone without the app. With App Links and
/// Universal Links wired, the same URL is handed to the app instead, and this
/// is the one place that knows what it means.
abstract final class SharedLinks {
  static final _ride = RegExp(r'^/r/(\d+)/?$');

  /// The in-app route for [uri], or null when it is not a shared link.
  static String? routeFor(Uri uri) {
    final match = _ride.firstMatch(uri.path);
    if (match == null) return null;
    final id = int.tryParse(match.group(1)!);
    if (id == null || id <= 0) return null;
    return Routes.rideDetail(id);
  }
}

/// Holds a shared link until the app can show it, then opens it on top of
/// home.
///
/// Two things rule out simply rewriting `/r/42` to `/ride/42`. On a cold start
/// the guard pins every location to `/splash` while the session boots — and
/// to onboarding or profile setup after that — so the link would be lost.
/// And a ride opened with `go` sits alone on the stack: no back button, and
/// Android's back press closes the app instead of leaving for the search.
///
/// So the link resolves to home, is parked here, and is pushed over home as
/// soon as the guard lets the session reach it. The push-notification path
/// solves the same problem in `PendingDeepLink`; this is its router-side twin,
/// because a web link arrives through the router rather than a tap stream.
class SharedLinkGate {
  String? _parked;

  /// Whether a link is waiting for the session to let it through.
  bool get hasPending => _parked != null;

  /// The router's redirect, with shared links folded in.
  ///
  /// [open] is called at most once per link, with the route to push, once the
  /// guard allows both the page the user is being sent to and the link itself.
  String? redirect({
    required SessionState session,
    required bool updateBlocks,
    required Uri uri,
    required String location,
    required void Function(String route) open,
  }) {
    final link = SharedLinks.routeFor(uri);
    if (link != null) _parked = link;

    // A shared link is a visit to home with a page on top of it; the guard
    // decides whether home is reachable yet, exactly as for any other launch.
    final wanted = link != null ? Routes.home : location;
    final guarded = AppGuard.redirect(
      session: session,
      updateBlocks: updateBlocks,
      location: wanted,
    );
    final destination = guarded ?? wanted;

    final parked = _parked;
    if (parked != null &&
        AppGuard.redirect(
              session: session,
              updateBlocks: updateBlocks,
              location: destination,
            ) ==
            null &&
        AppGuard.redirect(
              session: session,
              updateBlocks: updateBlocks,
              location: parked,
            ) ==
            null &&
        !_isGate(destination)) {
      _parked = null;
      open(parked);
    }

    return destination == location ? null : destination;
  }

  /// Screens a user passes through rather than stays on. Opening a ride over
  /// one of them would leave the gate underneath, reachable with back.
  static bool _isGate(String location) => const {
    Routes.splash,
    Routes.onboarding,
    Routes.profileSetup,
    Routes.blocked,
    Routes.updateRequired,
  }.contains(location);
}
