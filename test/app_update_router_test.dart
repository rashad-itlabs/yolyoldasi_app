import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/core/router/app_guard.dart';
import 'package:yolyoldasi/core/router/app_routes.dart';
import 'package:yolyoldasi/features/auth/presentation/bloc/session/session_bloc.dart';

/// The wall itself: whether the guard refuses to resolve anywhere but
/// `/update` while `GET /app-version` says `required`.
///
/// A bloc that knows it is blocked but a guard that lets the user past would
/// be worse than no check at all, so this is the half worth pinning down.
void main() {
  /// Every destination a blocked build might plausibly try to reach — the
  /// gates, the tabs, and a deep link arriving from a push notification.
  const everywhere = [
    Routes.splash,
    Routes.onboarding,
    Routes.login,
    Routes.profileSetup,
    Routes.blocked,
    Routes.home,
    Routes.bookings,
    Routes.chat,
    Routes.profile,
    Routes.settings,
    Routes.notifications,
    '/ride/42',
    '/chat/7',
  ];

  String? redirect({
    required SessionState session,
    required bool updateBlocks,
    required String location,
  }) => AppGuard.redirect(
    session: session,
    updateBlocks: updateBlocks,
    location: location,
  );

  group('a forced update', () {
    test('sends every other destination to the wall', () {
      for (final session in [
        const SessionState(),
        const SessionState(status: SessionStatus.signedOut),
        const SessionState(
          status: SessionStatus.signedOut,
          onboardingSeen: true,
        ),
        const SessionState(status: SessionStatus.needsProfile),
        const SessionState(status: SessionStatus.blocked),
        const SessionState(status: SessionStatus.ready),
      ]) {
        for (final location in everywhere) {
          expect(
            redirect(
              session: session,
              updateBlocks: true,
              location: location,
            ),
            Routes.updateRequired,
            reason: '${session.status} at $location must be walled off',
          );
        }
      }
    });

    test('leaves the wall itself alone', () {
      // Redirecting /update to /update would be an infinite loop, which
      // go_router answers by throwing rather than by showing anything.
      expect(
        redirect(
          session: const SessionState(status: SessionStatus.ready),
          updateBlocks: true,
          location: Routes.updateRequired,
        ),
        isNull,
      );
    });

    test('outranks a blocked account', () {
      // Both walls apply; the update one comes first, because a build that
      // cannot run cannot show the other screen properly either.
      expect(
        redirect(
          session: const SessionState(status: SessionStatus.blocked),
          updateBlocks: true,
          location: Routes.blocked,
        ),
        Routes.updateRequired,
      );
    });
  });

  group('without a forced update', () {
    test('nothing is sent to the wall', () {
      for (final session in [
        const SessionState(),
        const SessionState(status: SessionStatus.signedOut),
        const SessionState(status: SessionStatus.needsProfile),
        const SessionState(status: SessionStatus.blocked),
        const SessionState(status: SessionStatus.ready),
      ]) {
        for (final location in everywhere) {
          expect(
            redirect(
              session: session,
              updateBlocks: false,
              location: location,
            ),
            isNot(Routes.updateRequired),
            reason: '${session.status} at $location must not be walled off',
          );
        }
      }
    });

    test('the wall is not somewhere a signed-in user can linger', () {
      // The forced status can only clear by restarting onto a new build, but
      // if it ever does, the screen must not become a dead end of its own.
      expect(
        redirect(
          session: const SessionState(status: SessionStatus.ready),
          updateBlocks: false,
          location: Routes.updateRequired,
        ),
        Routes.home,
      );
    });

    test('the existing gates still work', () {
      expect(
        redirect(
          session: const SessionState(),
          updateBlocks: false,
          location: Routes.home,
        ),
        Routes.splash,
      );
      expect(
        redirect(
          session: const SessionState(status: SessionStatus.signedOut),
          updateBlocks: false,
          location: Routes.home,
        ),
        Routes.onboarding,
      );
      expect(
        redirect(
          session: const SessionState(
            status: SessionStatus.signedOut,
            onboardingSeen: true,
          ),
          updateBlocks: false,
          location: Routes.home,
        ),
        Routes.login,
      );
      expect(
        redirect(
          session: const SessionState(status: SessionStatus.needsProfile),
          updateBlocks: false,
          location: Routes.home,
        ),
        Routes.profileSetup,
      );
      expect(
        redirect(
          session: const SessionState(status: SessionStatus.blocked),
          updateBlocks: false,
          location: Routes.home,
        ),
        Routes.blocked,
      );
      expect(
        redirect(
          session: const SessionState(status: SessionStatus.ready),
          updateBlocks: false,
          location: Routes.home,
        ),
        isNull,
      );
    });
  });
}
