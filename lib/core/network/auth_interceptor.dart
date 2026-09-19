import 'dart:async';

import 'package:dio/dio.dart';

import '../services/token_storage.dart';
import 'api_endpoints.dart';

/// Stamps `Authorization: Bearer <token>` on every request and reports a 401
/// back to the session, per API.md §16.2.
///
/// The 401 handler only *signals*; clearing the token and routing to the sign-in
/// screen is the session bloc's job, so this interceptor stays free of any
/// dependency on the feature layer.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required TokenStorage tokens}) : _tokens = tokens;

  final TokenStorage _tokens;
  final StreamController<void> _unauthorized =
      StreamController<void>.broadcast();

  /// Emits whenever the API rejects the stored token.
  Stream<void> get onUnauthorized => _unauthorized.stream;

  /// Endpoints that answer 401 for reasons other than a dead session — there
  /// is no session yet on any of them. Signing the user out on those would be
  /// wrong, and on the sign-in screen it would be a redirect loop.
  static const Set<String> _publicPaths = {
    Api.authPhoneRequest,
    Api.authPhoneVerify,
    Api.cities,
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokens.token;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final isUnauthorized = err.response?.statusCode == 401;
    final path = err.requestOptions.path;
    if (isUnauthorized && !_publicPaths.contains(path)) {
      _unauthorized.add(null);
    }
    handler.next(err);
  }

  Future<void> dispose() => _unauthorized.close();
}
