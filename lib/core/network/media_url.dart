import '../config/app_config.dart';

/// Absolute URLs for the media the API points at.
abstract final class MediaUrl {
  /// [url] made absolute.
  ///
  /// The API promises absolute URLs (API.md §1), but avatars uploaded before
  /// 2026-10-17 were stored and served as `/storage/avatars/x.jpg`. Handed to
  /// the image loader as-is, a path like that loads nothing and the avatar
  /// stayed an empty circle. Resolved against the API's own host instead.
  static String resolve(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.hasScheme) return url;
    return Uri.parse(AppConfig.apiBaseUrl).resolveUri(uri).toString();
  }
}
