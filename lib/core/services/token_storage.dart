import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the Sanctum token lives between launches.
///
/// API.md §16.1 is explicit that this must not be `SharedPreferences`: the
/// token never expires for `device: "app"`, so it is a long-lived credential.
abstract interface class TokenStorage {
  /// The token held in memory. Synchronous so the auth interceptor can stamp a
  /// request without awaiting the keychain on every call.
  String? get token;

  /// Reads the persisted token into memory. Called once during boot.
  Future<String?> restore();

  Future<void> save(String token);

  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  static const String _key = 'sanctum_token';

  final FlutterSecureStorage _storage;
  String? _cached;

  @override
  String? get token => _cached;

  @override
  Future<String?> restore() async {
    // A wiped keychain entry or a locked device throws rather than returning
    // null; treat either as "no session" so boot never dead-ends.
    try {
      _cached = await _storage.read(key: _key);
    } catch (_) {
      _cached = null;
    }
    return _cached;
  }

  @override
  Future<void> save(String token) async {
    _cached = token;
    await _storage.write(key: _key, value: token);
  }

  @override
  Future<void> clear() async {
    _cached = null;
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      // Already gone, or the keychain is unavailable — the in-memory copy is
      // cleared either way, which is what the interceptor reads.
    }
  }
}

/// In-memory implementation for tests.
class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage([this._cached]);

  String? _cached;

  @override
  String? get token => _cached;

  @override
  Future<String?> restore() async => _cached;

  @override
  Future<void> save(String token) async => _cached = token;

  @override
  Future<void> clear() async => _cached = null;
}
