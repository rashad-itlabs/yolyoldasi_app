/// Compile-time / launch-time configuration.
abstract final class AppConfig {
  // No `appVersion`/`buildNumber` constants here. They drifted from
  // `pubspec.yaml` the first time someone bumped the build without editing
  // this file, and the force-update gate now decides whether the app opens
  // at all from that number — so it is read from the binary instead. See
  // `core/services/app_version_info.dart`.

  /// Root of the REST API described in `API.md`.
  ///
  /// API.md notes that both `yolyoldasi.az` and `yolyodasi.az` appear in the
  /// project, so the domain is overridable without a code change:
  ///
  /// ```
  /// flutter run --dart-define=API_BASE_URL=https://yolyoldasi.az/api/v1
  /// ```
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://yolyoldasi.az/api/v1',
  );

  /// A Sanctum token baked in at build time so a development build starts
  /// signed in:
  ///
  /// ```
  /// flutter run --dart-define=DEV_API_TOKEN=12|abcdef...
  /// ```
  ///
  /// Empty by default, which lands the app on the sign-in screen. It exists to
  /// skip the SMS round trip during development, not to replace it — the real
  /// flow is the two `/auth/phone/*` steps in API.md §3. A stale token is
  /// harmless: `GET /me` answers 401 and the app signs straight back out.
  static const String devApiToken = String.fromEnvironment('DEV_API_TOKEN');

  /// The OneSignal application this build reports to.
  ///
  /// Not a secret: it identifies the app to the relay and can do nothing on its
  /// own. The key that can actually *send* a notification is the REST API key,
  /// and that one lives only in the Laravel `.env` — a build that shipped it
  /// would hand every installer the ability to notify the whole user base.
  ///
  /// Overridable so a staging OneSignal app can be pointed at without a code
  /// change, and so a build can opt out of push entirely:
  ///
  /// ```
  /// flutter run --dart-define=ONESIGNAL_APP_ID=
  /// ```
  ///
  /// Empty disables the transport — [InactivePushService] takes over and the
  /// app falls back to noticing messages by polling while it is open.
  static const String oneSignalAppId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: '91e4f700-6a5e-43fd-99f2-0ad18ae85fc4',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// Multipart uploads. Dart only flushes the request body once it starts
  /// waiting for the response, so on a slow mobile connection the receive
  /// clock is also running while the photos go out.
  static const Duration uploadTimeout = Duration(seconds: 90);

  /// Logs every request and response body. Off by default because the bodies
  /// contain phone numbers and bearer tokens.
  static const bool logHttp = bool.fromEnvironment('LOG_HTTP');

  /// The chat screen has no realtime transport, so it re-reads the thread on
  /// this interval while it is on screen.
  static const Duration chatPollInterval = Duration(seconds: 8);

  /// How often the app re-reads `GET /conversations` while it is open, looking
  /// for a message in a thread the user is *not* currently reading.
  ///
  /// Slower than [chatPollInterval] on purpose: that one keeps one open thread
  /// live, this one only has to notice a new thread within a few seconds.
  /// Only runs in the foreground — a suspended app runs no timers, which is
  /// why the locked-phone case needs a push transport instead.
  static const Duration foregroundMessageCheck = Duration(seconds: 15);

  static const String defaultCountryCode = '+994';
  static const String countryIso = 'AZ';
}
