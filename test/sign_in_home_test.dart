import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yolyoldasi/app/app.dart';
import 'package:yolyoldasi/core/constants/app_constants.dart';
import 'package:yolyoldasi/core/di/app_dependencies.dart';
import 'package:yolyoldasi/core/network/api_client.dart';
import 'package:yolyoldasi/core/router/app_routes.dart';
import 'package:yolyoldasi/core/services/app_version_info.dart';
import 'package:yolyoldasi/core/services/push/local_notifications.dart';
import 'package:yolyoldasi/core/services/push/push_message.dart';
import 'package:yolyoldasi/core/services/push/push_service.dart';
import 'package:yolyoldasi/core/services/token_storage.dart';
import 'package:yolyoldasi/features/auth/domain/entities/auth_session.dart';
import 'package:yolyoldasi/features/auth/presentation/bloc/session/session_bloc.dart';
import 'package:yolyoldasi/features/auth/presentation/pages/login_page.dart';
import 'package:yolyoldasi/features/profile/domain/entities/user_enums.dart';
import 'package:yolyoldasi/features/rides/presentation/pages/search_home_page.dart';
import 'package:yolyoldasi/features/rides/presentation/widgets/search_form_card.dart';

/// Reported on a real phone: after the SMS code, the home screen came up
/// empty — white — with only the navigation bar drawn.
///
/// The whole app runs here, router and all, against a stubbed server. The
/// cause: accepting the code set the session to `booting`, the guard sent the
/// user to `/splash` (tearing the tab shell down), and `/me` answering within
/// the page transition built a new shell while the old one was still leaving.
/// Two copies of the shell's GlobalKey truncated the branch navigator, which a
/// release build paints as nothing at all.
void main() {
  setUpAll(() async {
    for (final code in ['az', 'ru', 'en']) {
      await initializeDateFormatting(code);
    }
  });

  testWidgets('sign-in pushed over the guest home lands on a drawn home', (
    tester,
  ) async {
    // Real-network timing: `/me` answers inside the page transition.
    final app = await _App.pump(
      tester,
      meDelay: const Duration(milliseconds: 400),
    );

    unawaited(app.router.push(Routes.login));
    await _frames(tester);
    expect(find.byType(LoginPage), findsOneWidget);

    await app.signIn();

    expect(tester.takeException(), isNull);
    expect(find.byType(LoginPage), findsNothing);
    _expectDrawnHome(tester);
    await app.dispose();
  });

  testWidgets('a fast /me does not leave sign-in stacked over home', (
    tester,
  ) async {
    // The guard is handed the location under a pushed route, never `/login`
    // itself, so with nothing in between the sign-in screen stayed on top.
    final app = await _App.pump(tester);

    unawaited(app.router.push(Routes.login));
    await _frames(tester);

    await app.signIn();

    expect(tester.takeException(), isNull);
    expect(find.byType(LoginPage), findsNothing);
    _expectDrawnHome(tester);
    await app.dispose();
  });

  testWidgets('sign-in reached from onboarding lands on a drawn home', (
    tester,
  ) async {
    // Here `/login` is the whole stack (onboarding replaces itself with it),
    // so there is nothing to pop and the guard sends the user home.
    final app = await _App.pump(
      tester,
      meDelay: const Duration(milliseconds: 400),
    );

    app.router.go(Routes.login);
    await _frames(tester);
    expect(find.byType(SearchHomePage, skipOffstage: false), findsNothing);

    await app.signIn();

    expect(tester.takeException(), isNull);
    expect(find.byType(LoginPage), findsNothing);
    _expectDrawnHome(tester);
    await app.dispose();
  });
}

/// The app on a guest home, with a way to accept a code.
class _App {
  _App(this.tester, this.tokens, this.dependencies);

  final WidgetTester tester;
  final InMemoryTokenStorage tokens;
  final AppDependencies dependencies;

  static Future<_App> pump(
    WidgetTester tester, {
    Duration meDelay = Duration.zero,
  }) async {
    final server = _Server(meDelay: meDelay);
    final tokens = InMemoryTokenStorage();
    SharedPreferences.setMockInitialValues({PrefKeys.onboardingSeen: true});
    final dependencies = await AppDependencies.bootstrap(
      preferences: await SharedPreferences.getInstance(),
      apiClient: server.client(tokens: tokens),
      tokenStorage: tokens,
      push: _FakePush(),
      localNotifications: LocalNotifications(plugin: _Plugin()),
      version: AppVersionInfo.unknown,
    );

    await tester.pumpWidget(YolYoldasiApp(dependencies: dependencies));
    await _frames(tester);
    expect(find.byType(SearchHomePage), findsOneWidget);
    return _App(tester, tokens, dependencies);
  }

  BuildContext get _context => tester.element(find.byType(Navigator).first);

  GoRouter get router => GoRouter.of(_context);

  /// What the sign-in screen does once the API accepts the code.
  Future<void> signIn() async {
    await tokens.save('token-42');
    _context.read<SessionBloc>().add(
      const SessionSignedIn(
        AuthSession(token: 'token-42', userId: 42),
        mode: UserMode.passenger,
      ),
    );
    await _frames(tester);
  }

  /// Takes the tree down and cancels the analytics flush timer that
  /// `app_open` arms, so no timer outlives the test.
  Future<void> dispose() async {
    await tester.pumpWidget(const SizedBox());
    unawaited(dependencies.analytics.flush());
    await _frames(tester);
  }
}

/// The home tab is on screen and laid out — not just present in the tree
/// behind a tab bar.
void _expectDrawnHome(WidgetTester tester) {
  expect(find.byType(SearchHomePage), findsOneWidget);
  expect(find.byType(SearchFormCard), findsOneWidget);
  expect(tester.getSize(find.byType(SearchFormCard)).height, greaterThan(0));
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _Server implements HttpClientAdapter {
  _Server({this.meDelay = Duration.zero});

  final Duration meDelay;

  ApiClient client({TokenStorage? tokens}) => ApiClient(
    tokens: tokens ?? InMemoryTokenStorage(),
    dio: Dio()..httpClientAdapter = this,
    baseUrl: 'https://example.test/api/v1',
  );

  static const _me = {
    'id': 42,
    'phone': '+994501234567',
    'phone_verified_at': '2026-09-15T12:00:00+04:00',
    'full_name': 'Rəşad Məmmədov',
    'photo_url': null,
    'gender': 'male',
    'birth_year': 1994,
    'city': {'id': 1, 'name': 'Bakı'},
    'active_mode': 'passenger',
    'has_driver_profile': false,
    'language_code': 'az',
    'is_admin': false,
    'stats': {
      'driver_rating': 0,
      'driver_review_count': 0,
      'driver_trip_count': 0,
      'passenger_rating': 0,
      'passenger_review_count': 0,
      'passenger_trip_count': 0,
    },
    'notification_preferences': {
      'push_enabled': true,
      'bookings': true,
      'messages': true,
      'reminders': true,
      'marketing': false,
    },
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final route = '${options.method} ${options.path}';
    // A real network: `/me` takes a moment, so the router gets to see the
    // session pass through `booting` on its way to `ready`.
    if (route == 'GET /me' && meDelay > Duration.zero) {
      await Future<void>.delayed(meDelay);
    }
    final (status, body) = _answer(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  (int, Object) _answer(RequestOptions options) {
    final signedIn = options.headers['Authorization'] != null;
    switch ('${options.method} ${options.path}') {
      case 'GET /me' || 'PUT /me/mode':
        return signedIn
            ? (200, {'data': _me})
            : (401, {'message': 'Unauthenticated.'});
      case 'GET /conversations/unread-count' ||
          'GET /notifications/unread-count':
        return (200, {'unread_total': 0});
      case 'POST /events':
        return (202, {'message': 'ok'});
    }
    return (
      200,
      {
        'data': <Object>[],
        'meta': {'current_page': 1, 'last_page': 1},
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakePush implements PushService {
  @override
  Stream<PushMessage> get foregroundMessages =>
      const Stream<PushMessage>.empty();

  @override
  Stream<PushMessage> get taps => const Stream<PushMessage>.empty();

  @override
  Stream<String> get tokenChanges => const Stream<String>.empty();

  @override
  String? get currentToken => null;

  @override
  String get provider => 'fake';

  @override
  Future<bool> start() async => true;

  @override
  Future<void> identify({
    required String externalId,
    String? languageCode,
  }) async {}

  @override
  Future<void> clear() async {}

  @override
  Future<void> dispose() async {}
}

/// Answers the calls sign-in makes (initialize, then clearing the tray) so the
/// app gets past them; anything else falls through to [Mock] and returns null.
class _Plugin extends Mock implements FlutterLocalNotificationsPlugin {
  @override
  Future<bool?> initialize(
    InitializationSettings initializationSettings, {
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async => true;

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> cancel(int id, {String? tag}) async {}
}
