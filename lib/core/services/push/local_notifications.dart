import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../localization/app_strings.dart';
import 'notification_channels.dart';
import 'push_message.dart';

/// Draws notifications, and owns the Android channels.
///
/// It **renders**; it does not deliver. When the app is backgrounded or dead,
/// the notification is drawn by the OS from the transport's own process and
/// none of this code runs. This exists for the three jobs the OS leaves to the
/// app:
///
/// 1. **Creating the channels** — and fixing their importance, which Android
///    freezes at creation ([PushChannel]).
/// 2. **Asking for permission** — `POST_NOTIFICATIONS` is declared in the
///    manifest but Android 13+ discards every notification until it is granted
///    at runtime.
/// 3. **Drawing the foreground notification** — FCM draws nothing while the app
///    is on screen, on either platform.
///
/// It also cancels: nothing else would clear the tray entry for a conversation
/// the user has since read.
class LocalNotifications {
  LocalNotifications({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  bool _ready = false;

  /// Fires when the user taps a notification this class drew.
  ///
  /// A tap on one the OS drew arrives through the transport instead, so both
  /// paths exist and both must end up in the same place.
  void Function(PushMessage message)? onTap;

  /// Creates the channels and wires the tap handler. Safe to call twice.
  ///
  /// [strings] names the channels in the user's language. Android keeps the
  /// name from the moment of creation, so a later language change does not
  /// rewrite it — a known and accepted wart, far cheaper than the alternative
  /// of deleting and recreating channels, which would reset the user's own
  /// per-channel settings.
  Future<void> initialize(AppStrings strings) async {
    if (_ready) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    // Permission is requested separately, in [requestPermission], so the prompt
    // appears when the app can explain itself rather than at cold start.
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin),
      onDidReceiveNotificationResponse: _onResponse,
    );

    await _createChannels(strings);
    _ready = true;
  }

  Future<void> _createChannels(AppStrings strings) async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;

    for (final channel in PushChannel.values) {
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          channel.id,
          strings.byKey(channel.nameKey),
          description: strings.byKey(channel.descriptionKey),
          importance: switch (channel.importance) {
            ChannelImportance.high => Importance.high,
            ChannelImportance.normal => Importance.defaultImportance,
            ChannelImportance.low => Importance.low,
          },
        ),
      );
    }
  }

  /// Asks for notification permission, returning whether it is granted.
  ///
  /// Android 13+ needs `POST_NOTIFICATIONS`; below that it is granted at
  /// install. On iOS this is the alert/badge/sound prompt, and it must be
  /// granted before APNs will issue a token at all.
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    final darwin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (darwin != null) {
      return await darwin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return false;
  }

  /// Whether notifications are currently allowed, without prompting.
  Future<bool> isPermitted() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    return true;
  }

  /// Draws [message] — the foreground case.
  ///
  /// [title] and [body] are passed in rather than read off the message so the
  /// caller can localize: the push carries the server's wording, but the app
  /// has the same strings in az/ru/en and knows which one the user reads.
  Future<void> show(
    PushMessage message, {
    required String title,
    required String body,
  }) async {
    if (!_ready) return;

    final channel = message.channel;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        // Only used if the channel does not exist yet; the real name comes
        // from the channel created in [_createChannels].
        channel.id,
        importance: switch (channel.importance) {
          ChannelImportance.high => Importance.high,
          ChannelImportance.normal => Importance.defaultImportance,
          ChannelImportance.low => Importance.low,
        },
        priority: channel.importance == ChannelImportance.high
            ? Priority.high
            : Priority.defaultPriority,
        // Collapses repeats from the same thread onto one entry instead of
        // stacking a banner per message.
        tag: message.collapseKey,
        groupKey: message.collapseKey,
      ),
      iOS: DarwinNotificationDetails(threadIdentifier: message.collapseKey),
    );

    await _plugin.show(
      message.collapseId,
      title,
      body,
      details,
      payload: jsonEncode(message.toData()),
    );
  }

  /// Clears the tray entry for a thread the user has just read.
  Future<void> cancelFor(PushMessage message) =>
      _plugin.cancel(message.collapseId, tag: message.collapseKey);

  /// Clears every notification this app has posted — used on sign-out, so the
  /// next account never sees the previous one's tray.
  Future<void> cancelAll() => _plugin.cancelAll();

  void _onResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      final data = jsonDecode(payload);
      if (data is! Map) return;
      onTap?.call(PushMessage.fromData(Map<String, dynamic>.from(data)));
    } on FormatException catch (error) {
      // A malformed payload is not worth crashing a tap over, but it does mean
      // the notification led nowhere — which is worth seeing in a debug run.
      debugPrint('Ignoring notification with unreadable payload: $error');
    }
  }
}
