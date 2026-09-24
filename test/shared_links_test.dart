import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/core/router/app_routes.dart';
import 'package:yolyoldasi/core/router/shared_links.dart';
import 'package:yolyoldasi/features/auth/presentation/bloc/session/session_bloc.dart';

/// A ride shared as `https://yolyoldasi.az/r/{id}` has to survive every gate
/// the app puts in front of it — boot, onboarding, profile setup — and then
/// open on top of home, exactly once.
void main() {
  group('SharedLinks.routeFor', () {
    test('maps a shared ride to its detail page', () {
      expect(
        SharedLinks.routeFor(Uri.parse('https://yolyoldasi.az/r/42')),
        Routes.rideDetail(42),
      );
      expect(SharedLinks.routeFor(Uri.parse('/r/42/')), Routes.rideDetail(42));
    });

    test('ignores anything that is not a shared ride', () {
      for (final path in [
        '/',
        '/r/',
        '/r/abc',
        '/r/0',
        '/r/42/x',
        '/ride/42',
      ]) {
        expect(SharedLinks.routeFor(Uri.parse(path)), isNull, reason: path);
      }
    });
  });

  group('SharedLinkGate', () {
    late SharedLinkGate gate;
    late List<String> opened;

    setUp(() {
      gate = SharedLinkGate();
      opened = [];
    });

    String? visit(
      SessionState session,
      String location, {
      bool blocks = false,
    }) => gate.redirect(
      session: session,
      updateBlocks: blocks,
      uri: Uri.parse(location),
      location: location,
      open: opened.add,
    );

    const ready = SessionState(status: SessionStatus.ready);
    const guest = SessionState(
      status: SessionStatus.signedOut,
      onboardingSeen: true,
    );

    test('a signed-in user lands on home with the ride on top', () {
      expect(visit(ready, '/r/42'), Routes.home);
      expect(opened, [Routes.rideDetail(42)]);
    });

    test('a guest can open it too — ride detail is open to guests', () {
      expect(visit(guest, '/r/42'), Routes.home);
      expect(opened, [Routes.rideDetail(42)]);
    });

    test('a cold start holds the link through boot', () {
      expect(visit(const SessionState(), '/r/42'), Routes.splash);
      expect(opened, isEmpty);
      expect(gate.hasPending, isTrue);

      // The session finishes booting and the guard re-runs on /splash.
      expect(visit(ready, Routes.splash), Routes.home);
      expect(opened, [Routes.rideDetail(42)]);
      expect(gate.hasPending, isFalse);
    });

    test('a first launch holds the link through onboarding', () {
      const fresh = SessionState(status: SessionStatus.signedOut);
      expect(visit(fresh, '/r/42'), Routes.onboarding);
      expect(opened, isEmpty);

      expect(visit(guest, Routes.onboarding), Routes.home);
      expect(opened, [Routes.rideDetail(42)]);
    });

    test('a new account holds the link through profile setup', () {
      const setup = SessionState(status: SessionStatus.needsProfile);
      expect(visit(setup, '/r/42'), Routes.profileSetup);
      expect(opened, isEmpty);

      expect(visit(ready, Routes.profileSetup), Routes.home);
      expect(opened, [Routes.rideDetail(42)]);
    });

    test('a forced update keeps the link from opening', () {
      expect(visit(ready, '/r/42', blocks: true), Routes.updateRequired);
      expect(opened, isEmpty);
    });

    test('opens once, however often the guard re-runs', () {
      visit(ready, '/r/42');
      visit(ready, Routes.home);
      visit(ready, Routes.home);
      expect(opened, [Routes.rideDetail(42)]);
    });

    test('ordinary navigation is left to the guard', () {
      expect(visit(ready, Routes.home), isNull);
      expect(visit(ready, '/ride/7'), isNull);
      expect(opened, isEmpty);
    });
  });
}
