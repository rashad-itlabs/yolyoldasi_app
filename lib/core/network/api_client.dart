import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../error/failure.dart';
import '../error/result.dart';
import '../services/token_storage.dart';
import '../types.dart';
import 'api_envelope.dart';
import 'api_error_mapper.dart';
import 'auth_interceptor.dart';

/// The one place the app talks HTTP.
///
/// Every method returns a [Result], so services and repositories never have to
/// catch [DioException] — the status-code table in API.md §1 is applied once,
/// here, by [ApiErrors].
class ApiClient {
  ApiClient({required TokenStorage tokens, Dio? dio, String? baseUrl})
    : _auth = AuthInterceptor(tokens: tokens),
      _dio = dio ?? Dio() {
    _dio.options = _dio.options.copyWith(
      baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      // Without this Laravel answers validation errors with an HTML redirect
      // instead of JSON (API.md §1).
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );
    _dio.interceptors.add(_auth);
    if (AppConfig.logHttp && kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }
  }

  final Dio _dio;
  final AuthInterceptor _auth;

  /// Fires when the API rejects the stored token; the session bloc listens.
  Stream<void> get onUnauthorized => _auth.onUnauthorized;

  // --------------------------------------------------------------- verbs

  /// A single resource, unwrapped from its `data` envelope.
  FutureResult<T> getObject<T>(
    String path, {
    Json? query,
    required T Function(Json json) parse,
  }) {
    return _send(
      () => _dio.get<dynamic>(path, queryParameters: _query(query)),
      (body) => parse(Envelope.object(body)),
    );
  }

  /// A flat list — used by endpoints that never paginate, like `/cities`.
  FutureResult<List<T>> getList<T>(
    String path, {
    Json? query,
    required T Function(Json json) parse,
  }) {
    return _send(
      () => _dio.get<dynamic>(path, queryParameters: _query(query)),
      (body) => Envelope.list(body).map(parse).toList(growable: false),
    );
  }

  /// One page of a paginated collection, with the cursor from `meta`.
  FutureResult<Paginated<T>> getPage<T>(
    String path, {
    Json? query,
    int? page,
    required T Function(Json json) parse,
  }) {
    return _send(
      () => _dio.get<dynamic>(
        path,
        queryParameters: _query({...?query, 'page': ?page}),
      ),
      (body) => Paginated<T>.fromBody(body, parse),
    );
  }

  FutureResult<T> post<T>(
    String path, {
    Json? body,
    Json? query,
    required T Function(Json json) parse,
  }) {
    return _send(
      () =>
          _dio.post<dynamic>(path, data: body, queryParameters: _query(query)),
      (data) => parse(Envelope.object(data)),
    );
  }

  FutureResult<T> put<T>(
    String path, {
    Json? body,
    required T Function(Json json) parse,
  }) {
    return _send(
      () => _dio.put<dynamic>(path, data: body),
      (data) => parse(Envelope.object(data)),
    );
  }

  FutureResult<T> patch<T>(
    String path, {
    Json? body,
    required T Function(Json json) parse,
  }) {
    return _send(
      () => _dio.patch<dynamic>(path, data: body),
      (data) => parse(Envelope.object(data)),
    );
  }

  FutureResult<T> delete<T>(
    String path, {
    Json? body,
    required T Function(Json json) parse,
  }) {
    return _send(
      () => _dio.delete<dynamic>(path, data: body),
      (data) => parse(Envelope.object(data)),
    );
  }

  /// The whole response body, envelope and all.
  ///
  /// For the handful of endpoints that put something useful *beside* `data`
  /// rather than inside it — `POST /ride-requests` answers with the request in
  /// `data` and the rides that already match it in `matches` (API.md §19).
  /// Unwrapping would throw the second half away.
  FutureResult<T> getFull<T>(
    String path, {
    Json? query,
    required T Function(Json body) parse,
  }) {
    return _send(
      () => _dio.get<dynamic>(path, queryParameters: _query(query)),
      (body) => parse(body is Map ? Json.from(body) : const {}),
    );
  }

  /// [getFull] for a write.
  FutureResult<T> postFull<T>(
    String path, {
    Json? body,
    required T Function(Json body) parse,
  }) {
    return _send(
      () => _dio.post<dynamic>(path, data: body),
      (data) => parse(data is Map ? Json.from(data) : const {}),
    );
  }

  /// A call whose response body carries nothing the caller needs.
  FutureResult<void> send(
    String method,
    String path, {
    Json? body,
    Json? query,
  }) {
    return _send<void>(
      () => _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: _query(query),
        options: Options(method: method),
      ),
      (_) {},
    );
  }

  /// A `multipart/form-data` upload. Dio sets the boundary itself, so the
  /// `Content-Type` header is removed rather than overwritten (API.md §16.6).
  FutureResult<T> upload<T>(
    String path, {
    required FormData form,
    String method = 'POST',
    required T Function(Json json) parse,
  }) {
    return _send(
      () => _dio.request<dynamic>(
        path,
        data: form,
        options: Options(method: method, headers: {'Content-Type': null}),
      ),
      (data) => parse(Envelope.object(data)),
    );
  }

  // --------------------------------------------------------------- plumbing

  Future<Result<T>> _send<T>(
    Future<Response<dynamic>> Function() request,
    T Function(Object? body) parse,
  ) async {
    try {
      final response = await request();
      return Ok(parse(response.data));
    } on DioException catch (error, stackTrace) {
      return Err(ApiErrors.map(error, stackTrace));
    } on Failure catch (failure) {
      return Err(failure);
    } catch (error, stackTrace) {
      // A parse error: the body came back in a shape the model did not expect.
      return Err(
        UnknownFailure(
          debugMessage: 'Response parsing failed: $error\n$stackTrace',
          cause: error,
        ),
      );
    }
  }

  /// Drops null values from a query string, so an unset filter simply does not
  /// appear rather than arriving as `key=null`.
  ///
  /// Request *bodies* are deliberately passed through untouched: `PATCH /me`
  /// distinguishes "leave my city alone" (key absent) from "clear my city"
  /// (key present, value null), and stripping nulls here would collapse the
  /// two. Deciding which keys to send is the model layer's job.
  static Json? _query(Json? input) {
    if (input == null) return null;
    final result = <String, dynamic>{};
    input.forEach((key, value) {
      if (value != null) result[key] = value;
    });
    return result;
  }

  Future<void> close() async {
    await _auth.dispose();
    _dio.close(force: true);
  }
}
