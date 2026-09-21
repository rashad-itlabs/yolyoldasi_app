import 'package:shared_preferences/shared_preferences.dart';

import '../../features/app_update/data/repositories/app_update_repository_impl.dart';
import '../../features/app_update/data/services/app_update_api_service.dart';
import '../../features/app_update/domain/repositories/app_update_repository.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/data/services/auth_api_service.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/bookings/data/repositories/booking_repository_impl.dart';
import '../../features/bookings/data/services/booking_api_service.dart';
import '../../features/bookings/domain/repositories/booking_repository.dart';
import '../../features/chat/data/repositories/chat_repository_impl.dart';
import '../../features/chat/data/services/chat_api_service.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/cities/data/repositories/city_repository_impl.dart';
import '../../features/cities/data/services/city_api_service.dart';
import '../../features/cities/domain/repositories/city_repository.dart';
import '../../features/notifications/data/repositories/notification_repository_impl.dart';
import '../../features/notifications/data/services/notification_api_service.dart';
import '../../features/notifications/domain/repositories/notification_repository.dart';
import '../../features/profile/data/repositories/driver_repository_impl.dart';
import '../../features/profile/data/repositories/user_repository_impl.dart';
import '../../features/profile/data/services/device_token_api_service.dart';
import '../../features/profile/data/services/driver_api_service.dart';
import '../../features/profile/data/services/user_api_service.dart';
import '../../features/profile/data/services/vehicle_api_service.dart';
import '../../features/profile/domain/repositories/driver_repository.dart';
import '../../features/profile/domain/repositories/user_repository.dart';
import '../../features/reports/data/repositories/report_repository_impl.dart';
import '../../features/reports/data/services/report_api_service.dart';
import '../../features/reports/domain/repositories/report_repository.dart';
import '../../features/reviews/data/repositories/review_repository_impl.dart';
import '../../features/reviews/data/services/review_api_service.dart';
import '../../features/reviews/domain/repositories/review_repository.dart';
import '../../features/rides/data/repositories/ride_repository_impl.dart';
import '../../features/rides/data/services/ride_api_service.dart';
import '../../features/rides/domain/repositories/ride_repository.dart';
import '../../features/settings/data/repositories/settings_repository_impl.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../config/app_config.dart';
import '../network/api_client.dart';
import '../services/app_version_info.dart';
import '../services/push/foreground_message_watcher.dart';
import '../services/push/local_notifications.dart';
import '../services/push/onesignal_push_service.dart';
import '../services/push/pending_deep_link.dart';
import '../services/push/push_service.dart';
import '../services/token_storage.dart';

/// Builds the object graph once, at boot, and hands the repositories to the
/// widget tree through `MultiRepositoryProvider`.
///
/// Plain constructor wiring rather than a locator package: the graph is shallow
/// (client → service → repository), it is all built in one place, and a test
/// can substitute any layer by passing its own [ApiClient] or repository.
class AppDependencies {
  AppDependencies._({
    required this.apiClient,
    required this.tokens,
    required this.version,
    required this.settings,
    required this.auth,
    required this.updates,
    required this.users,
    required this.drivers,
    required this.cities,
    required this.rides,
    required this.bookings,
    required this.chat,
    required this.reviews,
    required this.notifications,
    required this.reports,
    required this.push,
    required this.localNotifications,
    required this.pendingDeepLink,
    required this.foregroundMessages,
  });

  final ApiClient apiClient;
  final TokenStorage tokens;

  /// What version this build is, read from the binary at boot. The update
  /// gate compares it; the settings and profile screens display it.
  final AppVersionInfo version;

  /// The push transport — [OneSignalPushService], or [InactivePushService] in
  /// a build with no app id. See `core/services/push/push_service.dart`.
  final PushService push;

  /// Draws notifications and owns the Android channels. Live regardless of
  /// whether a transport is wired.
  final LocalNotifications localNotifications;

  /// Parks a notification tap until the session is ready to route it, and
  /// remembers which conversation is on screen.
  final PendingDeepLink pendingDeepLink;

  /// Notices a message for a thread the user is not reading, while the app is
  /// open. Needs no push transport; covers only the foreground.
  final ForegroundMessageWatcher foregroundMessages;

  final SettingsRepository settings;
  final AuthRepository auth;

  /// Whether this build is still allowed to run. Read before sign-in.
  final AppUpdateRepository updates;

  final UserRepository users;
  final DriverRepository drivers;
  final CityRepository cities;
  final RideRepository rides;
  final BookingRepository bookings;
  final ChatRepository chat;
  final ReviewRepository reviews;
  final NotificationRepository notifications;
  final ReportRepository reports;

  /// Wires everything up and restores the persisted session.
  ///
  /// [apiClient] and [tokens] are injectable so a widget test can drive the
  /// whole app against a stubbed Dio without touching the keychain.
  static Future<AppDependencies> bootstrap({
    required SharedPreferences preferences,
    ApiClient? apiClient,
    TokenStorage? tokenStorage,
    PushService? push,
    LocalNotifications? localNotifications,
    AppVersionInfo? version,
  }) async {
    final tokens = tokenStorage ?? SecureTokenStorage();
    final client = apiClient ?? ApiClient(tokens: tokens);

    // Injectable so a widget test can pretend to be any release it likes and
    // drive the update gate without a platform channel.
    final appVersion = version ?? await AppVersionInfo.read();

    // The session has to be in memory before the first request, or the app
    // would boot signed-out with a perfectly good token on disk.
    await tokens.restore();

    final settings = SettingsRepositoryImpl(preferences);
    await settings.load();

    final deviceTokens = DeviceTokenApiService(client);
    final userApi = UserApiService(client);

    final chat = ChatRepositoryImpl(ChatApiService(client));
    final deepLink = PendingDeepLink();

    return AppDependencies._(
      apiClient: client,
      tokens: tokens,
      version: appVersion,
      settings: settings,
      updates: AppUpdateRepositoryImpl(
        api: AppUpdateApiService(client),
        version: appVersion,
        settings: settings,
      ),
      auth: AuthRepositoryImpl(
        api: AuthApiService(client),
        deviceTokens: deviceTokens,
        tokens: tokens,
        unauthorized: client.onUnauthorized,
      ),
      users: UserRepositoryImpl(users: userApi, deviceTokens: deviceTokens),
      drivers: DriverRepositoryImpl(
        driver: DriverApiService(client),
        vehicles: VehicleApiService(client),
      ),
      cities: CityRepositoryImpl(CityApiService(client)),
      rides: RideRepositoryImpl(RideApiService(client)),
      bookings: BookingRepositoryImpl(BookingApiService(client)),
      chat: chat,
      reviews: ReviewRepositoryImpl(ReviewApiService(client)),
      notifications: NotificationRepositoryImpl(NotificationApiService(client)),
      reports: ReportRepositoryImpl(ReportApiService(client)),

      // OneSignal, unless a test passed its own or the app id was compiled
      // out — in which case the inactive transport takes over and the
      // foreground watcher below is the only thing noticing new messages.
      push: push ?? _defaultPushService(),
      localNotifications: localNotifications ?? LocalNotifications(),
      pendingDeepLink: deepLink,

      // The fallback for when push cannot deliver — permission refused, or no
      // app id in this build. Only covers the app being on screen; see
      // [AppStartup], which starts it only when the transport did not.
      foregroundMessages: ForegroundMessageWatcher(
        chat: chat,
        deepLink: deepLink,
      ),
    );
  }

  /// OneSignal when there is an app id to point it at, nothing otherwise.
  ///
  /// The empty case is real rather than defensive: `--dart-define=
  /// ONESIGNAL_APP_ID=` produces a build with no transport, and everything
  /// above this line — channels, permission, routing, the foreground watcher —
  /// still works. It is how the app is exercised without a relay.
  static PushService _defaultPushService() =>
      AppConfig.oneSignalAppId.isEmpty
      ? const InactivePushService()
      : OneSignalPushService();

  Future<void> dispose() async {
    await foregroundMessages.dispose();
    await push.dispose();
    await apiClient.close();
  }
}
