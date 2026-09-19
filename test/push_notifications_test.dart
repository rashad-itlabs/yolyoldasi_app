import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/core/network/api_client.dart';
import 'package:yolyoldasi/core/services/push/notification_channels.dart';
import 'package:yolyoldasi/core/services/push/pending_deep_link.dart';
import 'package:yolyoldasi/core/services/push/push_message.dart';
import 'package:yolyoldasi/core/services/push/push_service.dart';
import 'package:yolyoldasi/core/services/token_storage.dart';
import 'package:yolyoldasi/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:yolyoldasi/features/auth/data/services/auth_api_service.dart';
import 'package:yolyoldasi/features/auth/presentation/bloc/session/session_bloc.dart';
import 'package:yolyoldasi/features/notifications/domain/entities/app_notification.dart';
import 'package:yolyoldasi/features/profile/data/repositories/user_repository_impl.dart';
import 'package:yolyoldasi/features/profile/data/services/device_token_api_service.dart';
import 'package:yolyoldasi/features/profile/data/services/user_api_service.dart';
import 'package:yolyoldasi/features/settings/domain/repositories/settings_repository.dart';

/// Push delivery, from the wire payload down to where a tap lands — plus the
/// three defects that only bite once push is switched on.
void main() {
  group('unknown notification types', () {
    test('an unrecognised type is surfaced, not guessed', () {
      // The old fallback answered `bookingRequested`, so a renamed or mistyped
      // wire value rendered a chat push as a booking request and routed the tap
      // to the wrong screen, with no error anywhere.
      expect(
        NotificationType.fromApi('somethingNewTheServerKnows'),
        NotificationType.unknown,
      );
      expect(NotificationType.fromApi(null), NotificationType.unknown);
      expect(NotificationType.fromApi(''), NotificationType.unknown);

      expect(NotificationType.unknown.isKnown, isFalse);
      expect(NotificationType.newMessage.isKnown, isTrue);
    });

    test('every known wire value still round-trips', () {
      for (final type in NotificationType.values) {
        if (!type.isKnown) continue;
        expect(NotificationType.fromApi(type.apiValue), type);
      }
    });

    test('an unknown type still reaches the user, on the fallback channel', () {
      // Dropping it would be worse: a server that learns a new type before the
      // app does should still be able to say something.
      expect(
        PushChannel.forType(NotificationType.unknown),
        PushChannel.fallback,
      );
    });
  });

  group('notification channels', () {
    // Android freezes a channel's importance when the channel is created, and
    // no app update can raise it afterwards. These expectations are the record
    // of a decision that cannot be revisited after the first install.
    test('everything that may need to interrupt is created high', () {
      expect(PushChannel.messages.importance, ChannelImportance.high);
      expect(PushChannel.bookings.importance, ChannelImportance.high);
      expect(PushChannel.reminders.importance, ChannelImportance.high);
      expect(PushChannel.fallback.importance, ChannelImportance.high);
    });

    test('marketing is low and must stay low', () {
      expect(PushChannel.marketing.importance, ChannelImportance.low);
    });

    test('the fallback channel id matches the manifest', () {
      // AndroidManifest.xml declares this as
      // `com.google.firebase.messaging.default_notification_channel_id`. FCM
      // posts to it when a payload names no channel, so it has to be a channel
      // this app actually creates.
      expect(PushChannel.fallback.id, 'yolyoldasi_default');
    });

    test('every type has a channel and every channel is named', () {
      for (final type in NotificationType.values) {
        expect(PushChannel.forType(type), isNotNull, reason: type.name);
      }
      final ids = PushChannel.values.map((c) => c.id).toSet();
      expect(ids, hasLength(PushChannel.values.length));
    });
  });

  group('reading a push payload', () {
    test('the flat string map becomes the domain object', () {
      // FCM data values are strings only — there is no nesting and no ints.
      final message = PushMessage.fromData({
        'type': 'newMessage',
        'notification_id': '120',
        'conversation_id': '14',
        'ride_id': '7',
        'booking_id': '88',
        'actor_name': 'Rəşad',
        'created_at': '2026-09-19T21:04:11+04:00',
      });

      expect(message.type, NotificationType.newMessage);
      expect(message.notificationId, 120);
      expect(message.conversationId, 14);
      expect(message.actorName, 'Rəşad');
      expect(message.channel, PushChannel.messages);

      // A chat push opens the thread, not the booking it belongs to.
      expect(message.target, isA<ConversationTarget>());
      expect(PendingDeepLink.routeFor(message), '/chat/14');
    });

    test('the four characters "null" mean absent', () {
      // A server that string-interpolates a null id sends "null". Left alone it
      // would show up as a contact called "null".
      final message = PushMessage.fromData({
        'type': 'bookingConfirmed',
        'booking_id': '88',
        'ride_id': 'null',
        'conversation_id': '',
        'actor_name': 'null',
      });

      expect(message.rideId, isNull);
      expect(message.conversationId, isNull);
      expect(message.actorName, isNull);
      expect(message.bookingId, 88);
      expect(PendingDeepLink.routeFor(message), '/bookings/88');
    });

    test('a push with no ids at all is a dead link, not a crash', () {
      // API.md §13 warns every id can be null at once, when the subject has
      // been deleted.
      final message = PushMessage.fromData({'type': 'rideCancelled'});

      expect(message.isDeadLink, isTrue);
      expect(PendingDeepLink.routeFor(message), isNull);
    });

    test('a malformed payload degrades instead of throwing', () {
      // This parses inside a background isolate where nothing would catch it.
      final message = PushMessage.fromData({
        'type': 42,
        'conversation_id': 'not-a-number',
        'created_at': 'yesterday',
      });

      expect(message.type, NotificationType.unknown);
      expect(message.conversationId, isNull);
      expect(message.sentAt, isNull);
    });

    test('repeats in one thread collapse onto a single tray entry', () {
      // Otherwise a device coming back online shows thirty banners, and the
      // user turns notifications off for good.
      final first = PushMessage.fromData({
        'type': 'newMessage',
        'conversation_id': '14',
        'notification_id': '120',
      });
      final second = PushMessage.fromData({
        'type': 'newMessage',
        'conversation_id': '14',
        'notification_id': '121',
      });

      expect(first.collapseKey, 'conv_14');
      expect(second.collapseKey, first.collapseKey);
      expect(second.collapseId, first.collapseId);
    });

    test('data survives a round trip through the wire form', () {
      final original = PushMessage.fromData({
        'type': 'bookingRequested',
        'booking_id': '88',
        'actor_name': 'Aysel',
      });
      final restored = PushMessage.fromData(original.toData());

      expect(restored, original);
    });
  });

  group('a tap that arrives before the app is ready', () {
    test('is parked and drained once, not lost', () {
      // A cold-start tap arrives while the router still rewrites everything to
      // /splash, so navigating immediately loses the destination.
      final pending = PendingDeepLink();
      expect(pending.hasPending, isFalse);
      expect(pending.takeRoute(), isNull);

      pending.offer(
        PushMessage.fromData({'type': 'newMessage', 'conversation_id': '14'}),
      );

      expect(pending.hasPending, isTrue);
      expect(pending.takeRoute(), '/chat/14');
      expect(pending.hasPending, isFalse, reason: 'draining clears it');
      expect(pending.takeRoute(), isNull, reason: 'and does not repeat');
    });

    test('a newer tap wins — that is the notification the user pressed', () {
      final pending = PendingDeepLink()
        ..offer(
          PushMessage.fromData({'type': 'newMessage', 'conversation_id': '14'}),
        )
        ..offer(
          PushMessage.fromData({
            'type': 'bookingConfirmed',
            'booking_id': '88',
          }),
        );

      expect(pending.takeRoute(), '/bookings/88');
    });
  });

  group('signing out releases the device token', () {
    late _StubAdapter adapter;
    late _FakePushService push;
    late SessionBloc session;

    setUp(() {
      adapter = _StubAdapter()..reply(204, null);
      push = _FakePushService('fcm-token-abc');

      final tokens = InMemoryTokenStorage();
      final client = ApiClient(
        tokens: tokens,
        dio: Dio()..httpClientAdapter = adapter,
        baseUrl: 'https://example.test/api/v1',
      );

      session = SessionBloc(
        auth: AuthRepositoryImpl(
          api: AuthApiService(client),
          deviceTokens: DeviceTokenApiService(client),
          tokens: tokens,
          unauthorized: client.onUnauthorized,
        ),
        users: UserRepositoryImpl(
          users: UserApiService(client),
          deviceTokens: DeviceTokenApiService(client),
        ),
        settings: _FakeSettingsRepository(),
        push: push,
      );
      addTearDown(session.close);
    });

    Future<void> signOut() async {
      session.add(const SessionSignOutRequested());
      await session.stream.firstWhere(
        (state) => state.status == SessionStatus.signedOut,
      );
    }

    test('DELETE /me/device-tokens carries the token', () async {
      // API.md §5. Until this landed, SessionBloc called logout() with no
      // token, so `_releaseDeviceToken` returned on its first line every time
      // and the branch had never once executed. The moment push is switched on
      // that becomes a privacy defect: a signed-out user's phone keeps
      // receiving the next account's notifications.
      await signOut();

      final unregister = adapter.requests.firstWhere(
        (r) => r.path.contains('/me/device-tokens'),
        orElse: () => throw StateError(
          'no call to /me/device-tokens — the unregister path is dead again. '
          'Requests made: ${adapter.requests.map((r) => r.path).toList()}',
        ),
      );

      expect(unregister.method, 'DELETE');
      expect(
        (unregister.data as Map<String, dynamic>)['token'],
        'fcm-token-abc',
      );
    });

    test('the local registration is dropped too', () async {
      await signOut();

      expect(push.cleared, isTrue);
      expect(push.currentToken, isNull);
    });
  });

  test('the inactive transport registers nothing', () async {
    // What ships until a transport is configured: the channels, the permission
    // prompt and the routing are all live, and only delivery is missing. A null
    // token is what keeps the client from posting a placeholder the server
    // would later try to send to.
    const push = InactivePushService();

    expect(await push.start(), isFalse);
    expect(push.currentToken, isNull);
    expect(await push.tokenChanges.isEmpty, isTrue);
    expect(await push.taps.isEmpty, isTrue);
    expect(await push.foregroundMessages.isEmpty, isTrue);
  });
}

class _FakePushService implements PushService {
  _FakePushService(this._token);

  String? _token;
  bool cleared = false;

  @override
  String? get currentToken => _token;

  @override
  Future<bool> start() async => true;

  @override
  Stream<String> get tokenChanges => const Stream<String>.empty();

  @override
  Stream<PushMessage> get foregroundMessages =>
      const Stream<PushMessage>.empty();

  @override
  Stream<PushMessage> get taps => const Stream<PushMessage>.empty();

  @override
  Future<void> clear() async {
    cleared = true;
    _token = null;
  }

  @override
  Future<void> dispose() async {}
}

class _FakeSettingsRepository implements SettingsRepository {
  @override
  Future<void> load() async {}

  @override
  String? get languageCode => 'az';

  @override
  ThemeMode get themeMode => ThemeMode.system;

  @override
  bool get onboardingSeen => true;

  @override
  Future<void> setLanguageCode(String? code) async {}

  @override
  Future<void> setThemeMode(ThemeMode mode) async {}

  @override
  Future<void> setOnboardingSeen(bool seen) async {}

  @override
  Future<void> clearForSignOut() async {}
}

/// Records every request so a test can assert on one that is not the last.
class _StubAdapter implements HttpClientAdapter {
  int _status = 200;
  Object? _body;
  final List<RequestOptions> requests = [];

  void reply(int status, Object? body) {
    _status = status;
    _body = body;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      _body == null ? '' : jsonEncode(_body),
      _status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
