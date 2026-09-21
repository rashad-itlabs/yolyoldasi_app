import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/core/network/api_client.dart';
import 'package:yolyoldasi/core/services/token_storage.dart';
import 'package:yolyoldasi/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:yolyoldasi/features/auth/data/services/auth_api_service.dart';
import 'package:yolyoldasi/features/auth/domain/entities/auth_session.dart';
import 'package:yolyoldasi/features/auth/presentation/bloc/phone_sign_in/phone_sign_in_bloc.dart';
import 'package:yolyoldasi/features/auth/presentation/bloc/session/session_bloc.dart';
import 'package:yolyoldasi/features/profile/data/repositories/user_repository_impl.dart';
import 'package:yolyoldasi/features/profile/data/services/device_token_api_service.dart';
import 'package:yolyoldasi/features/profile/data/services/user_api_service.dart';
import 'package:yolyoldasi/features/profile/domain/entities/user_enums.dart';
import 'package:yolyoldasi/features/settings/domain/repositories/settings_repository.dart';

/// Driver or passenger, picked on the sign-in screen — the only place it is
/// picked. The choice only becomes real after `/me` has answered, and
/// `PUT /me/mode` waits rather than fires when the API would refuse it
/// (API.md §5).
void main() {
  late _StubAdapter adapter;
  late AuthRepositoryImpl auth;
  late SessionBloc session;

  setUp(() {
    adapter = _StubAdapter();
    final tokens = InMemoryTokenStorage();
    final client = ApiClient(
      tokens: tokens,
      dio: Dio()..httpClientAdapter = adapter,
      baseUrl: 'https://example.test/api/v1',
    );

    auth = AuthRepositoryImpl(
      api: AuthApiService(client),
      deviceTokens: DeviceTokenApiService(client),
      tokens: tokens,
      unauthorized: client.onUnauthorized,
    );

    session = SessionBloc(
      auth: auth,
      users: UserRepositoryImpl(
        users: UserApiService(client),
        deviceTokens: DeviceTokenApiService(client),
      ),
      settings: _FakeSettingsRepository(),
    );
    addTearDown(session.close);
  });

  Map<String, dynamic> me({
    String activeMode = 'passenger',
    bool hasDriverProfile = false,
    String fullName = 'Rəşad Məmmədov',
  }) => {
    'data': {
      'id': 42,
      'phone': '+994501234567',
      'full_name': fullName,
      'active_mode': activeMode,
      'has_driver_profile': hasDriverProfile,
    },
  };

  const token = AuthSession(token: '12|abcdef', userId: 42);

  group('PhoneSignInBloc', () {
    test('starts on the passenger side and remembers the pick', () async {
      final bloc = PhoneSignInBloc(auth: auth);
      addTearDown(bloc.close);

      expect(bloc.state.mode, UserMode.passenger);

      bloc.add(const PhoneSignInModeChanged(UserMode.driver));
      await bloc.stream.first;

      expect(bloc.state.mode, UserMode.driver);
      // The pick is made on the first step but only used after the second, so
      // it has to survive everything in between.
      bloc.add(const PhoneSignInPhoneChanged('50 123 45 67'));
      await bloc.stream.first;
      expect(bloc.state.mode, UserMode.driver);
    });
  });

  group('the mode chosen at sign-in', () {
    test('is applied once /me has answered', () async {
      adapter
        ..on(
          '/me/mode',
          200,
          me(
            activeMode: 'driver',
            hasDriverProfile: true,
            // Distinct so the test waits for the server's answer rather than
            // the optimistic flip that precedes it.
            fullName: 'Sürücü Rəşad',
          ),
        )
        ..on('/me', 200, me(hasDriverProfile: true));

      session.add(const SessionSignedIn(token, mode: UserMode.driver));
      await session.stream.firstWhere(
        (state) => state.user?.fullName == 'Sürücü Rəşad',
      );

      final put = adapter.requestFor('/me/mode');
      expect(put?.method, 'PUT');
      expect((put?.data as Map)['active_mode'], 'driver');
      expect(session.state.isDriverMode, isTrue);
    });

    test('costs nothing when it already matches the account', () async {
      adapter.on('/me', 200, me());

      session.add(const SessionSignedIn(token, mode: UserMode.passenger));
      await session.stream.firstWhere((state) => state.user != null);
      await Future<void>.delayed(Duration.zero);

      // `PUT /me/mode` would be a no-op request on every single sign-in.
      expect(adapter.requestFor('/me/mode'), isNull);
    });

    test('driver is not forced on an account with no car', () async {
      // §5 answers 422 for this, and spending the user's first second on an
      // error message is worse than opening where they can actually act.
      adapter.on('/me', 200, me());

      session.add(const SessionSignedIn(token, mode: UserMode.driver));
      await session.stream.firstWhere((state) => state.user != null);
      await Future<void>.delayed(Duration.zero);

      expect(adapter.requestFor('/me/mode'), isNull);
      expect(session.state.isDriverMode, isFalse);
      // Held, not dropped: nothing else in the app can pick the mode, so
      // losing it here would mean signing out to get back to the driver side.
      expect(session.state.pendingMode, UserMode.driver);
    });

    test('a held driver pick lands as soon as a car exists', () async {
      // The session has to be real for `SessionRefreshed` to do anything.
      adapter
        ..on('/me', 200, me())
        ..on('/auth/phone/verify', 200, {
          'token': '12|abcdef',
          'user': {'id': 42, 'phone': '+994501234567'},
        });
      await auth.verifyCode(phone: '+994501234567', code: '123456');

      session.add(const SessionSignedIn(token, mode: UserMode.driver));
      await session.stream.firstWhere((state) => state.user != null);
      await Future<void>.delayed(Duration.zero);
      expect(session.state.isDriverMode, isFalse);

      // Adding a first vehicle flips `has_driver_profile`, and the vehicle
      // page re-reads `/me` right after it saves.
      adapter
        ..on(
          '/me/mode',
          200,
          me(
            activeMode: 'driver',
            hasDriverProfile: true,
            // Distinct so the test waits for the server's answer rather than
            // the optimistic flip that precedes it.
            fullName: 'Sürücü Rəşad',
          ),
        )
        ..on('/me', 200, me(hasDriverProfile: true));

      session.add(const SessionRefreshed());
      await session.stream.firstWhere(
        (state) => state.user?.fullName == 'Sürücü Rəşad',
      );
      expect(session.state.isDriverMode, isTrue);

      final put = adapter.requestFor('/me/mode');
      expect((put?.data as Map)['active_mode'], 'driver');
      expect(session.state.pendingMode, isNull);
    });

    test('a refused switch rolls the session back', () async {
      // The account claims a driver profile but the server disagrees.
      adapter
        ..on('/me/mode', 422, {'message': 'Sürücü profili yoxdur.'})
        ..on('/me', 200, me(hasDriverProfile: true));

      session.add(const SessionSignedIn(token, mode: UserMode.driver));
      await session.stream.firstWhere((state) => state.failure != null);

      expect(session.state.isDriverMode, isFalse);
      expect(session.state.user, isNotNull);
    });
  });
}

/// Dio adapter that answers by path, so one test can script both `GET /me` and
/// `PUT /me/mode`. The most recently added matching rule wins, which lets a
/// test re-script a path mid-run — `/me` answering differently once a car
/// exists, say.
class _StubAdapter implements HttpClientAdapter {
  final List<({String path, int status, Object? body})> _rules = [];
  final List<RequestOptions> requests = [];

  void on(String path, int status, Object? body) =>
      _rules.add((path: path, status: status, body: body));

  RequestOptions? requestFor(String path) =>
      requests.where((r) => r.path.endsWith(path)).firstOrNull;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final rule = _rules.where((r) => options.path.endsWith(r.path)).lastOrNull;
    return ResponseBody.fromString(
      rule?.body == null ? '{}' : jsonEncode(rule!.body),
      rule?.status ?? 404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeSettingsRepository implements SettingsRepository {
  @override
  bool get onboardingSeen => true;

  @override
  ThemeMode get themeMode => ThemeMode.system;

  @override
  String? get languageCode => null;

  @override
  Future<void> load() async {}

  @override
  Future<void> setThemeMode(ThemeMode mode) async {}

  @override
  Future<void> setLanguageCode(String? code) async {}

  @override
  Future<void> setOnboardingSeen(bool seen) async {}

  @override
  Future<void> clearForSignOut() async {}

  @override
  String? get dismissedUpdateVersion => null;

  @override
  Future<void> setDismissedUpdateVersion(String? version) async {}
}
