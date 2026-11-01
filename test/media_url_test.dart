import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/core/config/app_config.dart';
import 'package:yolyoldasi/core/network/media_url.dart';

/// Reported: the profile photo did not show. The API sent the avatar as a
/// bare path, `/storage/avatars/x.jpg`, and a path alone loads nothing.
void main() {
  final host = Uri.parse(AppConfig.apiBaseUrl).origin;

  test('a bare storage path is completed with the API host', () {
    expect(
      MediaUrl.resolve('/storage/avatars/x.jpg'),
      '$host/storage/avatars/x.jpg',
    );
  });

  test('an absolute URL is left exactly as it came', () {
    const url = 'https://cdn.example.test/a/b.jpg?v=2';
    expect(MediaUrl.resolve(url), url);
  });
}
