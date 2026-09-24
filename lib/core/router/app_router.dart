import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/app_update/presentation/bloc/app_update/app_update_bloc.dart';
import '../../features/app_update/presentation/pages/update_required_page.dart';
import '../../features/auth/presentation/bloc/session/session_bloc.dart';
import '../../features/auth/presentation/pages/blocked_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/onboarding_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/bookings/presentation/pages/booking_detail_page.dart';
import '../../features/bookings/presentation/pages/bookings_page.dart';
import '../../features/bookings/presentation/pages/ride_bookings_page.dart';
import '../../features/chat/presentation/pages/chat_page.dart';
import '../../features/chat/presentation/pages/conversations_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/pages/documents_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/profile_setup_page.dart';
import '../../features/profile/presentation/pages/public_profile_page.dart';
import '../../features/profile/presentation/pages/referral_page.dart';
import '../../features/profile/presentation/pages/vehicle_page.dart';
import '../../features/reviews/presentation/pages/my_reviews_page.dart';
import '../../features/reviews/presentation/pages/write_review_page.dart';
import '../../features/ride_requests/presentation/pages/incoming_requests_page.dart';
import '../../features/ride_requests/presentation/pages/ride_requests_page.dart';
import '../../features/rides/presentation/bloc/publish_ride/publish_ride_bloc.dart';
import '../../features/rides/presentation/pages/my_rides_page.dart';
import '../../features/rides/presentation/pages/publish_ride_page.dart';
import '../../features/rides/presentation/pages/ride_detail_page.dart';
import '../../features/rides/presentation/pages/search_results_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/shell/presentation/pages/app_shell.dart';
import '../../features/shell/presentation/pages/home_tab.dart';
import '../extensions/context_extensions.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_states.dart';
import 'app_routes.dart';
import 'shared_links.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _bookingsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'bookings');
final _chatNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'chat');
final _profileNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

/// Builds the router around [session] and [update].
///
/// The guard itself lives in [AppGuard]; this only feeds it the current state
/// of both blocs. [_GuardRefresh] re-runs it whenever either changes — which
/// is how signing in, signing out, or a forced update landing mid-session
/// moves the user without any screen calling `go` itself.
GoRouter buildRouter({
  required SessionBloc session,
  required AppUpdateBloc update,
}) {
  final refresh = _GuardRefresh(session: session, update: update);
  final sharedLinks = SharedLinkGate();
  late final GoRouter router;

  router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    debugLogDiagnostics: false,

    // ------------------------------------------------------------------ guard
    // A redirect cannot push, so the shared ride is opened once the frame that
    // lands on home has been built.
    redirect: (context, state) => sharedLinks.redirect(
      session: session.state,
      updateBlocks: update.state.blocks,
      uri: state.uri,
      location: state.matchedLocation,
      open: (route) => WidgetsBinding.instance.addPostFrameCallback(
        (_) => router.push(route),
      ),
    ),

    errorBuilder: (context, state) => AppScaffold(
      title: context.l10n.errorTitle,
      body: ErrorState(message: state.error?.toString()),
    ),

    // ----------------------------------------------------------------- routes
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, _) => const OnboardingPage(),
      ),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginPage()),
      GoRoute(
        path: Routes.profileSetup,
        builder: (_, _) => const ProfileSetupPage(),
      ),
      GoRoute(path: Routes.blocked, builder: (_, _) => const BlockedPage()),
      GoRoute(
        path: Routes.updateRequired,
        builder: (_, _) => const UpdateRequiredPage(),
      ),

      // ------------------------------------------------------------- shell
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            routes: [
              GoRoute(path: Routes.home, builder: (_, _) => const HomeTab()),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _bookingsNavigatorKey,
            routes: [
              GoRoute(
                path: Routes.bookings,
                builder: (_, _) => const BookingsPage(),
                routes: [
                  GoRoute(
                    path: Routes.bookingDetailPath,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, state) => BookingDetailPage(
                      bookingId: Routes.idOf(state.pathParameters['bookingId']),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _chatNavigatorKey,
            routes: [
              GoRoute(
                path: Routes.chat,
                builder: (_, _) => const ConversationsPage(),
                routes: [
                  GoRoute(
                    path: Routes.conversationPath,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, state) => ChatPage(
                      conversationId: Routes.idOf(
                        state.pathParameters['conversationId'],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (_, _) => const ProfilePage(),
                routes: [
                  GoRoute(
                    path: Routes.editProfilePath,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, _) => const ProfileSetupPage(isEditing: true),
                  ),
                  GoRoute(
                    path: Routes.vehiclePath,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, _) => const VehiclePage(),
                  ),
                  GoRoute(
                    path: Routes.documentsPath,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, _) => const DocumentsPage(),
                  ),
                  GoRoute(
                    path: Routes.myReviewsPath,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, _) => const MyReviewsPage(),
                  ),
                  GoRoute(
                    path: Routes.referralPath,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, _) => const ReferralPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // --------------------------------------------------- full-screen pages
      GoRoute(
        path: Routes.searchResults,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const SearchResultsPage(),
      ),
      // Declared before `/ride/:rideId` so "publish" is never read as an id.
      GoRoute(
        path: Routes.publishRide,
        parentNavigatorKey: _rootNavigatorKey,
        // `extra` carries a route the driver already chose — from a
        // passenger's request or from the demand list. Anything else that
        // lands here is ignored rather than crashing the builder.
        builder: (_, state) => PublishRidePage(
          prefill: state.extra is RidePrefill
              ? state.extra! as RidePrefill
              : null,
        ),
      ),
      GoRoute(
        path: '/rides/mine',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const MyRidesPage(),
      ),

      // Declared before `/ride-requests` itself so "incoming" is never read as
      // a request id — same reason `publish` comes before `/ride/:rideId`.
      GoRoute(
        path: Routes.rideRequestsIncoming,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const IncomingRequestsPage(),
      ),
      GoRoute(
        path: Routes.rideRequests,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const RideRequestsPage(),
      ),
      GoRoute(
        path: Routes.rideDetailPath,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) =>
            RideDetailPage(rideId: Routes.idOf(state.pathParameters['rideId'])),
        routes: [
          GoRoute(
            path: Routes.rideEditPath,
            parentNavigatorKey: _rootNavigatorKey,
            builder: (_, state) => PublishRidePage(
              rideId: Routes.idOf(state.pathParameters['rideId']),
            ),
          ),
          GoRoute(
            path: Routes.rideBookingsPath,
            parentNavigatorKey: _rootNavigatorKey,
            builder: (_, state) => RideBookingsPage(
              rideId: Routes.idOf(state.pathParameters['rideId']),
            ),
          ),
        ],
      ),
      GoRoute(
        path: Routes.publicProfilePath,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => PublicProfilePage(
          userId: Routes.idOf(state.pathParameters['userId']),
        ),
      ),
      GoRoute(
        path: Routes.writeReviewPath,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => WriteReviewPage(
          bookingId: Routes.idOf(state.pathParameters['bookingId']),
        ),
      ),
      GoRoute(
        path: Routes.notifications,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const NotificationsPage(),
      ),
      GoRoute(
        path: Routes.settings,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const SettingsPage(),
      ),

      // A ride shared from the website (`https://yolyoldasi.az/r/{id}`). The
      // top-level redirect answers it before this is reached; the route exists
      // so the path matches rather than falling through to the error page.
      GoRoute(path: '/r/:rideId', redirect: (_, _) => Routes.home),
    ],
  );

  return router;
}

/// Bridges [SessionBloc] and [AppUpdateBloc] to go_router's [Listenable]-based
/// refresh.
///
/// Only the fields the redirect actually reads trigger a re-evaluation — a
/// profile edit, a badge count, or an *optional* update arriving must not
/// re-run the guard.
class _GuardRefresh extends ChangeNotifier {
  _GuardRefresh({required SessionBloc session, required AppUpdateBloc update}) {
    _status = session.state.status;
    _onboardingSeen = session.state.onboardingSeen;
    _blocked = update.state.blocks;

    _session = session.stream.listen((state) {
      if (state.status == _status && state.onboardingSeen == _onboardingSeen) {
        return;
      }
      _status = state.status;
      _onboardingSeen = state.onboardingSeen;
      notifyListeners();
    });

    _update = update.stream.listen((state) {
      if (state.blocks == _blocked) return;
      _blocked = state.blocks;
      notifyListeners();
    });
  }

  late SessionStatus _status;
  late bool _onboardingSeen;
  late bool _blocked;

  late final StreamSubscription<SessionState> _session;
  late final StreamSubscription<AppUpdateState> _update;

  @override
  void dispose() {
    _session.cancel();
    _update.cancel();
    super.dispose();
  }
}
