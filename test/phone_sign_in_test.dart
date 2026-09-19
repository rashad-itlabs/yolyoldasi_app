import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/core/error/failure.dart';
import 'package:yolyoldasi/core/error/result.dart';
import 'package:yolyoldasi/core/network/api_client.dart';
import 'package:yolyoldasi/core/services/token_storage.dart';
import 'package:yolyoldasi/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:yolyoldasi/features/auth/data/services/auth_api_service.dart';
import 'package:yolyoldasi/features/auth/presentation/bloc/phone_sign_in/phone_sign_in_bloc.dart';
import 'package:yolyoldasi/features/profile/data/services/device_token_api_service.dart';
import 'package:yolyoldasi/features/profile/domain/entities/user_enums.dart';

/// The two-step phone sign-in of API.md §3.
void main() {
  late InMemoryTokenStorage tokens;
  late _StubAdapter adapter;
  late AuthRepositoryImpl auth;

  setUp(() {
    tokens = InMemoryTokenStorage();
    adapter = _StubAdapter();
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
  });

  void scriptChallenge({String? code, int resendAfter = 60}) {
    adapter.on('/auth/phone/request', 200, {
      'message': 'Təsdiq kodu yaradıldı.',
      'phone': '+994505550001',
      'expires_in': 300,
      'resend_after': resendAfter,
      'code': ?code,
    });
  }

  void scriptSession() {
    adapter.on('/auth/phone/verify', 200, {
      'token': '9|ZD7nhf',
      'user': {
        'id': 6,
        'full_name': 'Test Sərnişin',
        'phone': '+994505550001',
        'active_mode': 'driver',
        'has_driver_profile': true,
      },
      'is_new_user': false,
    });
  }

  group('requesting a code', () {
    test(
      'sends the number as typed and keeps the one the server picks',
      () async {
        scriptChallenge(code: '752082');

        final result = await auth.requestCode('050 555 00 01');

        // §3: the server normalises, so sending the raw input is correct and the
        // canonical answer is what the next step must use.
        expect(
          adapter.bodyFor('/auth/phone/request')['phone'],
          '050 555 00 01',
        );
        final challenge = (result as Ok).value;
        expect(challenge.phone, '+994505550001');
        expect(challenge.expiresIn, const Duration(minutes: 5));
        expect(challenge.resendAfter, const Duration(minutes: 1));
        expect(challenge.devCode, '752082');
      },
    );

    test('carries no code once the API stops echoing one', () async {
      scriptChallenge();

      final challenge = (await auth.requestCode('0505550001') as Ok).value;

      // The banner that shows it disappears with the field.
      expect(challenge.devCode, isNull);
    });

    test('an empty number never reaches the network', () async {
      final result = await auth.requestCode('   ');

      expect((result as Err).failure, isA<ValidationFailure>());
      expect(adapter.requests, isEmpty);
    });

    test('the resend throttle arrives as a duration', () async {
      adapter.on('/auth/phone/request', 429, {
        'message': 'Yeni kod üçün 44 saniyə gözlə.',
        'retry_after': 44,
      });

      final failure = (await auth.requestCode('0505550001') as Err).failure;

      expect(failure, isA<RateLimitFailure>());
      expect(
        (failure as RateLimitFailure).retryAfter,
        const Duration(seconds: 44),
      );
      // The server already says it in the user's language.
      expect(failure.serverMessage, 'Yeni kod üçün 44 saniyə gözlə.');
    });

    test("Laravel's own limiter only sets the header, and that counts", () async {
      // §3: the IP limiter answers a bare "Too Many Attempts." with the wait in
      // `Retry-After` instead of the body.
      adapter.on(
        '/auth/phone/request',
        429,
        {'message': 'Too Many Attempts.'},
        headers: {
          'retry-after': ['60'],
        },
      );

      final failure = (await auth.requestCode('0505550001') as Err).failure;

      expect(
        (failure as RateLimitFailure).retryAfter,
        const Duration(seconds: 60),
      );
    });
  });

  group('verifying a code', () {
    test('stores the token and describes who it belongs to', () async {
      scriptSession();

      final result = await auth.verifyCode(
        phone: '+994505550001',
        code: '752082',
      );

      final body = adapter.bodyFor('/auth/phone/verify');
      expect(body['phone'], '+994505550001');
      expect(body['code'], '752082');
      // `app` is what makes the token non-expiring; `web` would drop it after
      // an hour.
      expect(body['device'], 'app');

      final session = (result as Ok).value;
      expect(session.token, '9|ZD7nhf');
      expect(session.userId, 6);
      expect(session.activeMode, UserMode.driver);
      expect(session.hasDriverProfile, isTrue);
      expect(tokens.token, '9|ZD7nhf');
      expect(auth.hasSession, isTrue);
    });

    test('a wrong code leaves no session behind', () async {
      adapter.on('/auth/phone/verify', 422, {
        'message': 'Kod yanlışdır.',
        'attempts_left': 4,
      });

      final result = await auth.verifyCode(
        phone: '+994505550001',
        code: '000000',
      );

      expect((result as Err).failure, isA<ValidationFailure>());
      expect(tokens.token, isNull);
      expect(auth.hasSession, isFalse);
    });

    test('a blocked account is told apart from a bad code', () async {
      adapter.on('/auth/phone/verify', 403, {
        'message': 'Hesabın bloklanıb. Dəstək ilə əlaqə saxla.',
      });

      final failure =
          (await auth.verifyCode(phone: '+994505550001', code: '752082') as Err)
              .failure;

      // The session bloc routes 403 to the blocked screen rather than the
      // sign-in error line.
      expect(failure, isA<PermissionFailure>());
    });
  });

  group('PhoneSignInBloc', () {
    test('verifies against the server number, not the typed one', () async {
      scriptChallenge();
      scriptSession();
      final bloc = PhoneSignInBloc(auth: auth);
      addTearDown(bloc.close);

      bloc.add(const PhoneSignInPhoneChanged('050 555 00 01'));
      bloc.add(const PhoneSignInCodeRequested());
      await bloc.stream.firstWhere((s) => s.step == PhoneSignInStep.code);

      bloc.add(const PhoneSignInCodeChanged('752082'));
      bloc.add(const PhoneSignInSubmitted());
      await bloc.stream.firstWhere((s) => s.session != null);

      // The typed form would be rejected; §3 wants the canonical one back.
      expect(adapter.bodyFor('/auth/phone/verify')['phone'], '+994505550001');
      expect(bloc.state.resendIn, 60);
      await bloc.close();
    });

    test('a wrong code clears the boxes but keeps the challenge', () async {
      scriptChallenge();
      adapter.on('/auth/phone/verify', 422, {'message': 'Kod yanlışdır.'});
      final bloc = PhoneSignInBloc(auth: auth);
      addTearDown(bloc.close);

      bloc.add(const PhoneSignInPhoneChanged('0505550001'));
      bloc.add(const PhoneSignInCodeRequested());
      await bloc.stream.firstWhere((s) => s.step == PhoneSignInStep.code);

      bloc.add(const PhoneSignInCodeChanged('000000'));
      bloc.add(const PhoneSignInSubmitted());
      await bloc.stream.firstWhere((s) => s.status.isFailure);

      expect(bloc.state.code, isEmpty);
      // Re-entering the number to try the same code again would be absurd.
      expect(bloc.state.challenge, isNotNull);
      expect(bloc.state.step, PhoneSignInStep.code);
      await bloc.close();
    });

    test(
      'a throttled request runs the clock instead of repeating itself',
      () async {
        adapter.on('/auth/phone/request', 429, {
          'message': 'Yeni kod üçün 44 saniyə gözlə.',
          'retry_after': 44,
        });
        final bloc = PhoneSignInBloc(auth: auth);
        addTearDown(bloc.close);

        bloc.add(const PhoneSignInPhoneChanged('0505550001'));
        bloc.add(const PhoneSignInCodeRequested());
        await bloc.stream.firstWhere((s) => s.status.isFailure);

        expect(bloc.state.resendIn, 44);
        // Asking again before the wait is over would only earn another 429.
        expect(bloc.state.canRequestCode, isFalse);
        await bloc.close();
      },
    );

    test('changing the number drops the previous number\'s wait', () async {
      scriptChallenge();
      final bloc = PhoneSignInBloc(auth: auth);
      addTearDown(bloc.close);

      bloc.add(const PhoneSignInPhoneChanged('0505550001'));
      bloc.add(const PhoneSignInCodeRequested());
      await bloc.stream.firstWhere((s) => s.step == PhoneSignInStep.code);
      expect(bloc.state.resendIn, 60);

      bloc.add(const PhoneSignInPhoneEditRequested());
      await bloc.stream.firstWhere((s) => s.step == PhoneSignInStep.phone);

      // The throttle is per number, so a different one starts clean.
      expect(bloc.state.resendIn, 0);
      expect(bloc.state.canRequestCode, isTrue);
      await bloc.close();
    });
  });

  group('ending a session', () {
    test('signing out clears it even when the API fails', () async {
      scriptSession();
      await auth.verifyCode(phone: '+994505550001', code: '752082');

      adapter.on('/auth/logout', 500, {'message': 'boom'});
      await auth.logout();

      expect(tokens.token, isNull);
      expect(auth.hasSession, isFalse);
    });

    test('a failed deletion leaves the session intact', () async {
      scriptSession();
      await auth.verifyCode(phone: '+994505550001', code: '752082');

      adapter.on('/auth/account', 500, {'message': 'boom'});
      final result = await auth.deleteAccount();

      expect(result, isA<Err<void>>());
      // Deletion is irreversible; a failure must not look like it worked.
      expect(auth.hasSession, isTrue);
    });
  });
}

/// Dio adapter that answers by path, so one test can script both sign-in steps.
/// The most recently added matching rule wins.
class _StubAdapter implements HttpClientAdapter {
  final List<
    ({
      String path,
      int status,
      Object? body,
      Map<String, List<String>>? headers,
    })
  >
  _rules = [];
  final List<RequestOptions> requests = [];

  void on(
    String path,
    int status,
    Object? body, {
    Map<String, List<String>>? headers,
  }) => _rules.add((path: path, status: status, body: body, headers: headers));

  RequestOptions? requestFor(String path) =>
      requests.where((r) => r.path.endsWith(path)).lastOrNull;

  Map<String, dynamic> bodyFor(String path) =>
      Map<String, dynamic>.from(requestFor(path)?.data as Map? ?? const {});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final rule = _rules.where((r) => options.path.endsWith(r.path)).lastOrNull;
    return ResponseBody.fromString(
      jsonEncode(rule?.body ?? {'message': 'not scripted'}),
      rule?.status ?? 404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...?rule?.headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
