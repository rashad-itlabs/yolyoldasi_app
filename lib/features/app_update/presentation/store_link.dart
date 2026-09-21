import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../profile/domain/entities/user_enums.dart';

/// Getting the user from the update screen to the store listing.
abstract final class StoreLink {
  /// The server's link when it gave one, this platform's otherwise.
  ///
  /// The fallback is what makes the forced screen safe to ship before anyone
  /// has filled the admin field in: a wall with no way past it is worse than
  /// no wall at all.
  static Uri resolve(String? fromServer) {
    final given = fromServer?.trim();
    if (given != null && given.isNotEmpty) {
      final parsed = Uri.tryParse(given);
      if (parsed != null && parsed.hasScheme) return parsed;
    }

    return Uri.parse(
      DevicePlatform.current == DevicePlatform.ios
          ? AppLinks.appStoreSearchUrl
          : AppLinks.playStoreUrl,
    );
  }

  /// Opens the listing outside the app, so the store app handles it rather
  /// than an in-app web view that cannot install anything.
  ///
  /// Returns false when nothing could be opened — the caller says so instead
  /// of leaving the user tapping a button that does nothing.
  static Future<bool> open(String? fromServer) async {
    try {
      return await launchUrl(
        resolve(fromServer),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}
