import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yolyoldasi/core/localization/app_localizations.dart';
import 'package:yolyoldasi/core/router/app_routes.dart';
import 'package:yolyoldasi/core/theme/app_theme.dart';
import 'package:yolyoldasi/features/app_update/presentation/bloc/app_update/app_update_bloc.dart';
import 'package:yolyoldasi/features/auth/presentation/bloc/session/session_bloc.dart';
import 'package:yolyoldasi/features/profile/data/models/user_model.dart';
import 'package:yolyoldasi/features/profile/domain/entities/user_enums.dart';
import 'package:yolyoldasi/features/shell/presentation/bloc/badges/badges_bloc.dart';
import 'package:yolyoldasi/features/shell/presentation/pages/app_shell.dart';

/// The dock under the four tabs, and the publish button a driver gets in its
/// middle.
///
/// The real [AppShell] runs inside a real go_router shell route; only the
/// pages behind the tabs are stand-ins.
void main() {
  setUpAll(() => registerFallbackValue(const BadgesRefreshed()));

  testWidgets('a passenger gets four tabs and no publish button', (
    tester,
  ) async {
    await _Shell.pump(tester, mode: UserMode.passenger);

    for (final label in ['Axtarış', 'Bronlar', 'Söhbət', 'Profil']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.byTooltip('Elan ver'), findsNothing);
    expect(find.text('Elan ver'), findsNothing);
  });

  testWidgets('a driver gets the publish button between the middle tabs', (
    tester,
  ) async {
    await _Shell.pump(tester, mode: UserMode.driver);

    for (final label in ['Elanlar', 'Sorğular', 'Söhbət', 'Profil']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    final button = find.byTooltip('Elan ver');
    expect(button, findsOneWidget);

    final x = tester.getCenter(button).dx;
    expect(tester.getCenter(find.text('Sorğular')).dx, lessThan(x));
    expect(tester.getCenter(find.text('Söhbət')).dx, greaterThan(x));
    expect(x, moreOrLessEquals(tester.view.physicalSize.width / 2 / 3));
    // It rises out of the dock rather than sitting in its row.
    expect(
      tester.getTopLeft(button).dy,
      lessThan(tester.getTopLeft(find.text('Sorğular')).dy - 30),
    );
  });

  testWidgets('the publish button opens publishing', (tester) async {
    await _Shell.pump(tester, mode: UserMode.driver);

    await tester.tap(find.byTooltip('Elan ver'));
    await tester.pumpAndSettle();

    expect(find.text('publish page'), findsOneWidget);
  });

  testWidgets('a tab switches branch and re-reads the badges', (tester) async {
    final shell = await _Shell.pump(tester, mode: UserMode.passenger);
    expect(find.text('page ${Routes.home}'), findsOneWidget);

    await tester.tap(find.text('Söhbət'));
    await tester.pumpAndSettle();

    expect(find.text('page ${Routes.chat}'), findsOneWidget);
    verify(() => shell.badges.add(const BadgesRefreshed())).called(1);
  });

  testWidgets('a guest is sent to sign-in by any tab but search', (
    tester,
  ) async {
    await _Shell.pump(tester);

    await tester.tap(find.text('Bronlar'));
    await tester.pumpAndSettle();

    expect(find.text('login page'), findsOneWidget);
  });

  testWidgets('unread messages show on the chat tab', (tester) async {
    await _Shell.pump(tester, mode: UserMode.passenger, unreadMessages: 3);

    expect(
      find.descendant(of: find.byType(Badge), matching: find.text('3')),
      findsOneWidget,
    );
  });

  testWidgets('switching to driver mode brings the button in', (tester) async {
    final modes = StreamController<SessionState>.broadcast();
    addTearDown(modes.close);
    await _Shell.pump(tester, mode: UserMode.passenger, states: modes.stream);
    expect(find.byTooltip('Elan ver'), findsNothing);

    modes.add(_signedIn(UserMode.driver));
    // One frame to rebuild in driver mode, one for the animation to take its
    // start time, then a slice of the way in.
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byTooltip('Elan ver'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Elanlar'), findsOneWidget);
    await tester.tap(find.byTooltip('Elan ver'));
    await tester.pumpAndSettle();
    expect(find.text('publish page'), findsOneWidget);
  });
}

SessionState _signedIn(UserMode mode) => SessionState(
  status: SessionStatus.ready,
  user: UserModel.fromJson({
    'id': 42,
    'phone': '+994501234567',
    'full_name': 'Rəşad Məmmədov',
    'active_mode': mode.apiValue,
    'has_driver_profile': true,
    'language_code': 'az',
  }),
);

class _Shell {
  _Shell(this.badges);

  final BadgesBloc badges;

  static Future<_Shell> pump(
    WidgetTester tester, {
    UserMode? mode,
    int unreadMessages = 0,
    Stream<SessionState>? states,
  }) async {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final session = _MockSession();
    whenListen(
      session,
      states ?? const Stream<SessionState>.empty(),
      initialState: mode == null
          ? const SessionState(status: SessionStatus.signedOut)
          : _signedIn(mode),
    );
    final badges = _MockBadges();
    whenListen(
      badges,
      const Stream<BadgesState>.empty(),
      initialState: BadgesState(unreadMessages: unreadMessages),
    );
    final update = _MockUpdate();
    whenListen(
      update,
      const Stream<AppUpdateState>.empty(),
      initialState: const AppUpdateState(),
    );

    Widget page(String name) => Scaffold(body: Center(child: Text(name)));
    final router = GoRouter(
      initialLocation: Routes.home,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => AppShell(navigationShell: shell),
          branches: [
            for (final path in [
              Routes.home,
              Routes.bookings,
              Routes.chat,
              Routes.profile,
            ])
              StatefulShellBranch(
                routes: [
                  GoRoute(path: path, builder: (_, _) => page('page $path')),
                ],
              ),
          ],
        ),
        GoRoute(
          path: Routes.publishRide,
          builder: (_, _) => page('publish page'),
        ),
        GoRoute(path: Routes.login, builder: (_, _) => page('login page')),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<SessionBloc>.value(value: session),
          BlocProvider<BadgesBloc>.value(value: badges),
          BlocProvider<AppUpdateBloc>.value(value: update),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          locale: const Locale('az'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return _Shell(badges);
  }
}

class _MockSession extends MockBloc<SessionEvent, SessionState>
    implements SessionBloc {}

class _MockBadges extends MockBloc<BadgesEvent, BadgesState>
    implements BadgesBloc {}

class _MockUpdate extends MockBloc<AppUpdateEvent, AppUpdateState>
    implements AppUpdateBloc {}
