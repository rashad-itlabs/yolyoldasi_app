import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../../config/app_config.dart';
import 'push_message.dart';
import 'push_service.dart';

/// Push over OneSignal — the transport that makes a locked phone ring.
///
/// OneSignal is a relay in front of FCM and APNs rather than a third channel:
/// it holds the Firebase server key and the APNs auth key on its own servers,
/// which is why this app ships no `google-services.json` and no
/// `GoogleService-Info.plist`. Only the app id below is needed, and it is not a
/// secret — the REST API key that can actually *send* lives on the Laravel
/// side and never enters a build.
///
/// **Addressing is by account, not by device.** [identify] calls
/// `OneSignal.login()` with the API's user id, and from that moment the server
/// says "notify user 42" and OneSignal fans it out to every device that id has
/// ever been seen on. That matters more than it sounds: the old
/// `POST /me/device-tokens` path only reaches phones whose token the app
/// successfully registered, so a failed POST, a token rotation between
/// launches, or a reinstall all leave a device silently unreachable. An alias
/// has none of those gaps. The token is still registered — see [currentToken]
/// — but as a fallback and an audit trail, not the primary route.
///
/// Delivery itself never runs through this class. When the phone is locked and
/// the app is dead the notification is drawn by the OS from the OneSignal
/// SDK's own process; what follows only sees what happens once Dart is alive.
class OneSignalPushService implements PushService {
  OneSignalPushService({String? appId})
    : _appId = appId ?? AppConfig.oneSignalAppId;

  final String _appId;

  final StreamController<String> _tokens = StreamController<String>.broadcast();
  final StreamController<PushMessage> _foreground =
      StreamController<PushMessage>.broadcast();
  final StreamController<PushMessage> _taps =
      StreamController<PushMessage>.broadcast();

  bool _initialized = false;

  /// The external id this device is currently logged in under, so a second
  /// [identify] for the same account does not re-run the login round trip.
  String? _externalId;

  @override
  String get provider => 'onesignal';

  /// The OneSignal **subscription id**, not an FCM token.
  ///
  /// It is what `include_subscription_ids` takes in the REST API, and it is
  /// what `POST /me/device-tokens` stores — the `provider` field is what tells
  /// the server which of the two it is holding. Null until the SDK has
  /// registered, which on iOS cannot happen before permission is granted.
  @override
  String? get currentToken => OneSignal.User.pushSubscription.id;

  @override
  Stream<String> get tokenChanges => _tokens.stream;

  @override
  Stream<PushMessage> get foregroundMessages => _foreground.stream;

  @override
  Stream<PushMessage> get taps => _taps.stream;

  /// Initializes the SDK, wires the listeners, and asks for permission.
  ///
  /// Safe to call repeatedly — initialization happens once, and asking for
  /// permission that is already granted is a no-op that simply reports the
  /// current answer.
  @override
  Future<bool> start() async {
    if (_appId.isEmpty) return false;

    if (!_initialized) {
      _initialized = true;

      OneSignal.Debug.setLogLevel(
        kDebugMode ? OSLogLevel.warn : OSLogLevel.none,
      );
      OneSignal.initialize(_appId);

      OneSignal.User.pushSubscription.addObserver(_onSubscriptionChanged);
      OneSignal.Notifications.addForegroundWillDisplayListener(_onForeground);
      OneSignal.Notifications.addClickListener(_onClick);
    }

    // `false`: no second trip to the system settings screen after a refusal.
    // The app has its own place to explain that — the notification settings
    // page — and a prompt the user did not ask for lands worse than an
    // explanation they did.
    final granted = await OneSignal.Notifications.requestPermission(false);

    // Permission alone does not mean subscribed: `optOut()` survives a
    // reinstall-free relaunch, so a device that was opted out stays silent
    // with permission granted until it is opted back in.
    if (granted && OneSignal.User.pushSubscription.optedIn == false) {
      await OneSignal.User.pushSubscription.optIn();
    }

    return granted;
  }

  /// `OneSignal.login()` — the one call this whole integration exists for.
  ///
  /// Everything before it is device-scoped: notifications can only be aimed at
  /// this handset, by an id the server may or may not have. After it, the
  /// account itself is addressable.
  @override
  Future<void> identify({
    required String externalId,
    String? languageCode,
  }) async {
    if (_appId.isEmpty || externalId.isEmpty) return;

    if (_externalId != externalId) {
      _externalId = externalId;
      await OneSignal.login(externalId);
    }

    // Picks which of the az/ru/en headings the server sends with every push
    // this device is shown. Without it OneSignal falls back to the device
    // locale, which is not always the language the account reads in.
    if (languageCode != null && languageCode.isNotEmpty) {
      await OneSignal.User.setLanguage(languageCode);
    }
  }

  /// Detaches the device from the account, so the next person to sign in on
  /// this phone does not inherit the previous one's notifications.
  ///
  /// `logout()` moves the device back to an anonymous, device-scoped user
  /// rather than unsubscribing it; the subscription survives, it is simply no
  /// longer reachable through the old external id.
  @override
  Future<void> clear() async {
    if (!_initialized) return;
    _externalId = null;
    await OneSignal.logout();
  }

  @override
  Future<void> dispose() async {
    if (_initialized) {
      OneSignal.User.pushSubscription.removeObserver(_onSubscriptionChanged);
      OneSignal.Notifications.removeForegroundWillDisplayListener(_onForeground);
      OneSignal.Notifications.removeClickListener(_onClick);
    }
    await _tokens.close();
    await _foreground.close();
    await _taps.close();
  }

  void _onSubscriptionChanged(OSPushSubscriptionChangedState state) {
    final id = state.current.id;
    if (id == null || id.isEmpty) return;
    if (_tokens.isClosed) return;
    _tokens.add(id);
  }

  /// A push that landed while the app was on screen.
  ///
  /// [OSNotificationWillDisplayEvent.preventDefault] suppresses OneSignal's own
  /// banner so the app can draw its own instead. That is not duplication for
  /// its own sake: the app's renderer localizes the type line, picks the right
  /// Android channel, and collapses repeats from one conversation onto a single
  /// tray entry — none of which the relay can do. The cost is that a foreground
  /// push is not counted as "confirmed delivered" in the OneSignal dashboard.
  void _onForeground(OSNotificationWillDisplayEvent event) {
    event.preventDefault();
    if (_foreground.isClosed) return;
    _foreground.add(_toMessage(event.notification));
  }

  /// A tap, including one on a notification that cold-started the app.
  ///
  /// The plugin buffers clicks that arrive before a listener is attached and
  /// flushes them once one is, so the tap that launched the process is not lost
  /// to the gap before [start] runs.
  void _onClick(OSNotificationClickEvent event) {
    if (_taps.isClosed) return;
    _taps.add(_toMessage(event.notification));
  }

  /// Reads the flat `data` block the Laravel side sends.
  ///
  /// OneSignal exposes it as `additionalData`. Everything in it is a string —
  /// the same constraint FCM imposes and the same one [PushMessage.fromData]
  /// is written against, so the two transports are interchangeable at this
  /// seam. A push with no data at all still produces a message: the type
  /// degrades to `unknown`, which lands on the fallback channel rather than
  /// being dropped.
  static PushMessage _toMessage(OSNotification notification) =>
      PushMessage.fromData(
        notification.additionalData ?? const {},
        title: notification.title,
        body: notification.body,
      );
}
