import 'dart:io';

import 'package:dio/dio.dart';

import '../error/failure.dart';
import '../types.dart';

/// Turns a [DioException] into the [Failure] the domain layer speaks in,
/// following the status-code table in API.md §1.
abstract final class ApiErrors {
  static Failure map(Object error, [StackTrace? stackTrace]) {
    if (error is Failure) return error;
    if (error is! DioException) {
      return UnknownFailure(debugMessage: error.toString(), cause: error);
    }

    final response = error.response;
    if (response != null) return _fromResponse(response, error);

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => TimeoutFailure(
        debugMessage: error.message,
        cause: error,
      ),
      DioExceptionType.cancel => AuthFailure(
        FailureCode.cancelled,
        debugMessage: error.message,
        cause: error,
      ),
      DioExceptionType.connectionError => NetworkFailure(
        debugMessage: error.message,
        cause: error,
      ),
      DioExceptionType.badCertificate => NetworkFailure(
        debugMessage: 'Bad TLS certificate',
        cause: error,
      ),
      DioExceptionType.unknown =>
        error.error is SocketException
            ? NetworkFailure(debugMessage: error.message, cause: error)
            : UnknownFailure(debugMessage: error.message, cause: error),
      DioExceptionType.badResponse => ServerFailure(
        debugMessage: error.message,
        cause: error,
      ),
    };
  }

  static Failure _fromResponse(Response<dynamic> response, DioException cause) {
    final status = response.statusCode ?? 0;
    final body = response.data is Map
        ? Json.from(response.data as Map)
        : <String, dynamic>{};
    final message = body['message'] is String
        ? body['message'] as String
        : null;
    final debug = 'HTTP $status ${response.requestOptions.path}';

    return switch (status) {
      401 => AuthFailure(
        FailureCode.unauthenticated,
        serverMessage: message,
        debugMessage: debug,
        cause: cause,
      ),
      403 => PermissionFailure(
        serverMessage: message,
        debugMessage: debug,
        cause: cause,
      ),
      404 => NotFoundFailure(
        serverMessage: message,
        debugMessage: debug,
        cause: cause,
      ),
      409 => ConflictFailure(
        serverMessage: message,
        debugMessage: debug,
        cause: cause,
      ),
      422 => ValidationFailure(
        FailureCode.invalidInput,
        errors: _errors(body),
        serverMessage: message,
        debugMessage: debug,
        cause: cause,
      ),
      // Laravel's PostTooLargeException comes with an empty message, and
      // nginx's with an HTML page — neither is anything to show.
      413 => ValidationFailure(
        FailureCode.fileTooLarge,
        field: 'file',
        debugMessage: debug,
        cause: cause,
      ),
      429 => RateLimitFailure(
        retryAfter: _retryAfter(body, response.headers),
        serverMessage: message,
        debugMessage: debug,
        cause: cause,
      ),
      >= 500 => ServerFailure(
        serverMessage: message,
        debugMessage: debug,
        cause: cause,
      ),
      _ => UnknownFailure(
        statusCode: status,
        serverMessage: message,
        debugMessage: debug,
        cause: cause,
      ),
    };
  }

  /// How long a 429 wants the caller to wait.
  ///
  /// The body wins: the app's own throttles put `retry_after` there with a
  /// number meant for a countdown, while the `Retry-After` header is what
  /// Laravel's generic `throttle` middleware sends and is rounded up to the
  /// next minute boundary. Both are seconds.
  static Duration? _retryAfter(Json body, Headers headers) {
    final fromBody = body['retry_after'];
    final seconds = switch (fromBody) {
      final int value => value,
      final num value => value.round(),
      final String value => int.tryParse(value),
      _ => null,
    };
    final resolved =
        seconds ?? int.tryParse(headers.value('retry-after')?.trim() ?? '');

    // A zero or negative wait is the same as none, and would otherwise start a
    // countdown that never ticks.
    return (resolved == null || resolved <= 0)
        ? null
        : Duration(seconds: resolved);
  }

  /// Laravel's `errors` map. Absent on business-rule 422s (`abort(422, '...')`),
  /// which is why the client has to handle both shapes — see API.md §1.
  static Map<String, List<String>> _errors(Json body) {
    final raw = body['errors'];
    if (raw is! Map) return const {};
    final result = <String, List<String>>{};
    raw.forEach((key, value) {
      if (key is! String) return;
      if (value is List) {
        result[key] = value.map((m) => m.toString()).toList(growable: false);
      } else if (value is String) {
        result[key] = [value];
      }
    });
    return result;
  }
}
