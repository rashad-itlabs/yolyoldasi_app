import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/core/error/failure.dart';
import 'package:yolyoldasi/core/error/result.dart';
import 'package:yolyoldasi/core/localization/app_strings.dart';
import 'package:yolyoldasi/core/network/api_client.dart';
import 'package:yolyoldasi/core/services/token_storage.dart';
import 'package:yolyoldasi/core/utils/failure_message.dart';

/// Drives [ApiClient] against a stubbed transport, so the status-code table in
/// API.md §1 is exercised without a server.
void main() {
  late InMemoryTokenStorage tokens;
  late Dio dio;
  late _StubAdapter adapter;
  late ApiClient client;

  setUp(() {
    tokens = InMemoryTokenStorage();
    adapter = _StubAdapter();
    dio = Dio()..httpClientAdapter = adapter;
    client = ApiClient(
      tokens: tokens,
      dio: dio,
      baseUrl: 'https://example.test/api/v1',
    );
  });

  group('headers', () {
    test('always asks for JSON', () async {
      // Without `Accept: application/json` Laravel answers validation errors
      // with an HTML redirect (API.md §1).
      adapter.reply(200, {'data': {}});
      await client.getObject('/me', parse: (json) => json);

      expect(adapter.lastRequest?.headers['Accept'], 'application/json');
    });

    test('stamps the bearer token once there is one', () async {
      adapter.reply(200, {'data': {}});
      await client.getObject('/me', parse: (json) => json);
      expect(adapter.lastRequest?.headers['Authorization'], isNull);

      await tokens.save('12|abcdef');
      adapter.reply(200, {'data': {}});
      await client.getObject('/me', parse: (json) => json);
      expect(adapter.lastRequest?.headers['Authorization'], 'Bearer 12|abcdef');
    });
  });

  group('error mapping', () {
    Future<Failure> failureFor(int status, [Object? body]) async {
      adapter.reply(status, body ?? {'message': 'nope'});
      final result = await client.getObject('/me', parse: (json) => json);
      return (result as Err).failure;
    }

    test('401 becomes an unauthenticated AuthFailure', () async {
      final failure = await failureFor(401);
      expect(failure, isA<AuthFailure>());
      expect(failure.code, FailureCode.unauthenticated);
    });

    test(
      '403 becomes a PermissionFailure carrying the server message',
      () async {
        final failure = await failureFor(403, {'message': 'Hesab bloklanıb'});
        expect(failure, isA<PermissionFailure>());
        expect(failure.serverMessage, 'Hesab bloklanıb');
      },
    );

    test('404 becomes a NotFoundFailure', () async {
      expect(await failureFor(404), isA<NotFoundFailure>());
    });

    test('409 becomes a ConflictFailure', () async {
      // §10: this is "you already applied to this ride", and the booking flow
      // has to tell it apart from a validation error.
      final failure = await failureFor(409);
      expect(failure, isA<ConflictFailure>());
      expect(failure.code, FailureCode.alreadyExists);
    });

    test('422 with an errors map keeps the field messages', () async {
      final failure = await failureFor(422, {
        'message': 'The given data was invalid.',
        'errors': {
          'price_per_seat': ['Qiymət 1-500 aralığında olmalıdır.'],
        },
      });

      expect(failure, isA<ValidationFailure>());
      expect(
        (failure as ValidationFailure).messageFor('price_per_seat'),
        contains('1-500'),
      );
    });

    test('422 without an errors map still carries the prose', () async {
      // §1: a business-rule violation answers with `message` only, and there
      // is no machine code to map it to.
      final failure = await failureFor(422, {
        'message': 'Bu səfər aktiv deyil',
      });

      expect(failure, isA<ValidationFailure>());
      expect((failure as ValidationFailure).errors, isEmpty);
      expect(failure.serverMessage, 'Bu səfər aktiv deyil');
    });

    test('429 becomes tooManyRequests', () async {
      final failure = await failureFor(429, {'message': 'Too Many Attempts.'});
      expect(failure.code, FailureCode.tooManyRequests);
      // Nothing said how long to wait, so "unknown" — not "no wait".
      expect((failure as RateLimitFailure).retryAfter, isNull);
    });

    test('429 carries the wait the body names', () async {
      final failure = await failureFor(429, {
        'message': 'Yeni kod üçün 44 saniyə gözlə.',
        'retry_after': 44,
      });
      expect(
        (failure as RateLimitFailure).retryAfter,
        const Duration(seconds: 44),
      );
    });

    test('500 becomes a ServerFailure', () async {
      expect(await failureFor(500), isA<ServerFailure>());
    });

    test('413 says the file is too large, not "unexpected error"', () async {
      // Laravel's PostTooLargeException arrives with an empty message.
      final failure = await failureFor(413, {'message': ''});
      expect(failure.code, FailureCode.fileTooLarge);
      expect(failure.serverMessage, isNull);
    });

    test('an unlisted status is kept, so the message can name it', () async {
      final failure = await failureFor(418, {'message': ''});
      expect(failure, isA<UnknownFailure>());
      expect((failure as UnknownFailure).statusCode, 418);
      final az = AppStrings.of('az');
      expect(failure.message(az), '${az.errUnknown} (418)');
    });
  });

  group('session expiry', () {
    test('a 401 on a protected path reports to the session', () async {
      final expiries = <void>[];
      final subscription = client.onUnauthorized.listen(expiries.add);
      addTearDown(subscription.cancel);

      adapter.reply(401, {'message': 'Unauthenticated.'});
      await client.getObject('/me', parse: (json) => json);
      await Future<void>.delayed(Duration.zero);

      expect(expiries, hasLength(1));
    });

    test('a 401 from a sign-in endpoint does not', () async {
      // There is no session to expire on `/auth/phone/*`, and reporting one
      // would bounce the user off the screen they are signing in on.
      final expiries = <void>[];
      final subscription = client.onUnauthorized.listen(expiries.add);
      addTearDown(subscription.cancel);

      adapter.reply(401, {'message': 'Unauthenticated.'});
      await client.post('/auth/phone/verify', parse: (json) => json);
      await Future<void>.delayed(Duration.zero);

      expect(expiries, isEmpty);
    });
  });

  group('request bodies', () {
    test('an explicit null survives into a PATCH body', () async {
      // Clearing a field is `key: null` on the wire; stripping it would turn
      // "clear my city" into "leave it alone".
      adapter.reply(200, {'data': {}});
      await client.patch(
        '/me',
        body: {'city_id': null, 'full_name': 'Aysel'},
        parse: (json) => json,
      );

      final sent = adapter.lastRequest?.data as Map<String, dynamic>;
      expect(sent.containsKey('city_id'), isTrue);
      expect(sent['city_id'], isNull);
    });

    test('a null query parameter is dropped', () async {
      adapter.reply(200, {'data': []});
      await client.getList(
        '/bookings',
        query: {'status': null},
        parse: (json) => json,
      );

      expect(
        adapter.lastRequest?.queryParameters.containsKey('status'),
        isFalse,
      );
    });
  });

  test('a malformed body fails without throwing', () async {
    adapter.reply(200, {'data': 'not an object'});
    final result = await client.getObject(
      '/me',
      parse: (json) => json['id'] as int,
    );

    expect(result, isA<Err<int>>());
  });
}

/// Minimal Dio adapter that replays one canned response.
class _StubAdapter implements HttpClientAdapter {
  int _status = 200;
  Object? _body;
  RequestOptions? lastRequest;

  void reply(int status, Object? body) {
    _status = status;
    _body = body;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      _body == null ? '' : jsonEncode(_body),
      _status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
