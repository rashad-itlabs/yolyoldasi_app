import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/core/error/failure.dart';
import 'package:yolyoldasi/core/error/result.dart';
import 'package:yolyoldasi/core/network/api_client.dart';
import 'package:yolyoldasi/core/network/api_envelope.dart';
import 'package:yolyoldasi/core/services/push/foreground_message_watcher.dart';
import 'package:yolyoldasi/core/services/push/notification_channels.dart';
import 'package:yolyoldasi/core/services/push/pending_deep_link.dart';
import 'package:yolyoldasi/core/services/push/push_message.dart';
import 'package:yolyoldasi/core/services/push/push_service.dart';
import 'package:yolyoldasi/core/services/token_storage.dart';
import 'package:yolyoldasi/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:yolyoldasi/features/auth/data/services/auth_api_service.dart';
import 'package:yolyoldasi/features/auth/presentation/bloc/session/session_bloc.dart';
import 'package:yolyoldasi/features/chat/domain/entities/conversation.dart';
import 'package:yolyoldasi/features/chat/domain/repositories/chat_repository.dart';
import 'package:yolyoldasi/features/notifications/domain/entities/app_notification.dart';
import 'package:yolyoldasi/features/profile/data/repositories/user_repository_impl.dart';
import 'package:yolyoldasi/features/profile/data/services/device_token_api_service.dart';
import 'package:yolyoldasi/features/profile/data/services/user_api_service.dart';
import 'package:yolyoldasi/features/profile/domain/entities/app_user.dart';
import 'package:yolyoldasi/features/profile/domain/entities/user_enums.dart';
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

  group('an announcement from the admin panel', () {
    // API.md §13. These two carry their own wording and have all three
    // deep-link ids null *by design*. Every rule in this file about "no ids
    // means the subject was deleted" has to make an exception for them, and
    // the failure mode if it does not is quiet: a perfectly good service
    // notice renders as "this no longer exists" and a tap on it errors.
    AppNotification announcement(NotificationType type) => AppNotification(
      id: 310,
      type: type,
      createdAt: DateTime.utc(2026, 9, 21),
      payload: const {
        'heading': 'Texniki fasilə',
        'content': 'Sabah 02:00–04:00 arası tətbiq işləməyəcək.',
      },
    );

    test('is not a dead link, though it targets nothing', () {
      for (final type in [
        NotificationType.adminMessage,
        NotificationType.adminMarketing,
      ]) {
        final item = announcement(type);
        expect(item.target, isA<NotificationTarget>(), reason: type.name);
        expect(item.isDeadLink, isFalse, reason: type.name);
      }
    });

    test('a genuinely dead link is still called one', () {
      // The exception above must not swallow the case it was carved out of.
      final orphan = AppNotification(
        id: 1,
        type: NotificationType.bookingConfirmed,
        createdAt: DateTime.utc(2026, 9, 21),
      );
      expect(orphan.isDeadLink, isTrue);
    });

    test('its text comes from the payload, not from the type', () {
      final item = announcement(NotificationType.adminMessage);
      expect(item.heading, 'Texniki fasilə');
      expect(item.body, 'Sabah 02:00–04:00 arası tətbiq işləməyəcək.');
    });

    test('no other type reads that payload', () {
      // `heading` / `content` are the admin's keys. A booking whose payload
      // happened to carry them must not have its localized title overwritten.
      final booking = AppNotification(
        id: 2,
        type: NotificationType.bookingConfirmed,
        createdAt: DateTime.utc(2026, 9, 21),
        payload: const {'heading': 'nope', 'content': 'nope'},
      );

      expect(booking.heading, isNull);
      expect(booking.body, isNull);
    });

    test('a blank heading falls back rather than showing an empty title', () {
      final blank = AppNotification(
        id: 3,
        type: NotificationType.adminMessage,
        createdAt: DateTime.utc(2026, 9, 21),
        payload: const {'heading': '   ', 'content': 'Mətn'},
      );

      expect(blank.heading, isNull, reason: 'so the type line is used');
      expect(blank.body, 'Mətn');
    });

    test('a promotion lands on the channel that can never interrupt', () {
      // The only type that reaches `marketing`, whose low importance is frozen
      // at creation and cannot be raised later.
      expect(
        PushChannel.forType(NotificationType.adminMarketing),
        PushChannel.marketing,
      );
      expect(
        PushChannel.forType(NotificationType.adminMessage),
        PushChannel.fallback,
      );
    });

    test('two notices stack in the tray instead of replacing each other', () {
      // The server omits `collapse_id` for an announcement on purpose. With no
      // ids to tell two apart, both would land on tray entry 0 and the second
      // would overwrite the first — so the text is the identity here.
      final outage = PushMessage.fromData(
        const {'type': 'adminMessage'},
        title: 'Texniki fasilə',
        body: 'Sabah 02:00–04:00.',
      );
      final promo = PushMessage.fromData(
        const {'type': 'adminMessage'},
        title: 'Endirim',
        body: 'Bu həftə 20%.',
      );

      expect(outage.collapseId, isNot(promo.collapseId));
      expect(
        outage.collapseId,
        PushMessage.fromData(
          const {'type': 'adminMessage'},
          title: 'Texniki fasilə',
          body: 'Sabah 02:00–04:00.',
        ).collapseId,
        reason: 'the same notice twice is still one entry',
      );

      // Grouped rather than merged: Android gathers them under one summary.
      expect(outage.collapseKey, 'announcement');
      expect(promo.collapseKey, 'announcement');
    });

    test('tapping one opens the notification centre, not an error', () {
      // The push `data` for an announcement carries no ids at all — API.md §13
      // says not even `notification_id`, because one request serves every
      // recipient. The full text lives in the list, so that is where it leads.
      final pending = PendingDeepLink()
        ..offer(PushMessage.fromData({'type': 'adminMarketing'}));

      expect(pending.takeRoute(), '/notifications');
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

  group('registering a device names the account', () {
    // API.md §5. The external id is what lets the server address a *user*
    // instead of hunting for their devices, and it is the whole reason a
    // reinstall or a rotated subscription still reaches the phone. If it stops
    // travelling, nothing breaks loudly — push simply starts missing people.
    late _StubAdapter adapter;
    late DeviceTokenApiService service;

    setUp(() {
      adapter = _StubAdapter()..reply(201, {'data': {}});
      service = DeviceTokenApiService(
        ApiClient(
          tokens: InMemoryTokenStorage(),
          dio: Dio()..httpClientAdapter = adapter,
          baseUrl: 'https://example.test/api/v1',
        ),
      );
    });

    Map<String, dynamic> lastBody() =>
        adapter.requests.last.data as Map<String, dynamic>;

    test('the subscription id travels with its provider and alias', () async {
      await service.register(
        token: 'sub-id-abc',
        platform: DevicePlatform.ios,
        provider: 'onesignal',
        externalId: '42',
      );

      expect(lastBody(), {
        'token': 'sub-id-abc',
        'platform': 'ios',
        'provider': 'onesignal',
        'external_id': '42',
      });
    });

    test('neither is sent as null when the transport has none', () async {
      // Both are `sometimes` on the server, so an explicit null would
      // overwrite a good value recorded on a previous launch.
      await service.register(
        token: 'sub-id-abc',
        platform: DevicePlatform.android,
      );

      expect(lastBody(), {'token': 'sub-id-abc', 'platform': 'android'});
    });
  });

  group('a message while the app is open but elsewhere', () {
    // The half that needs no push transport: the app is running, so it can ask.
    // Covers "on another screen" only — a backgrounded app runs no timers, and
    // that is why the locked-phone case needs a transport.
    late _FakeChatRepository chat;
    late PendingDeepLink deepLink;
    late ForegroundMessageWatcher watcher;

    const me = 42;
    const them = 7;

    late List<PushMessage> seen;

    setUp(() {
      chat = _FakeChatRepository();
      deepLink = PendingDeepLink();
      watcher = ForegroundMessageWatcher(chat: chat, deepLink: deepLink);
      seen = <PushMessage>[];
      watcher.messages.listen(seen.add);
      addTearDown(watcher.dispose);
    });

    /// One pass, then drained.
    ///
    /// The drain is not optional: the watcher publishes on a broadcast stream,
    /// which delivers in a microtask, so asserting straight after `checkNow()`
    /// would read an empty list whatever happened — and every "stays quiet"
    /// expectation below would pass without testing anything.
    Future<void> tick() async {
      await watcher.checkNow();
      await pumpEventQueue();
    }

    Conversation thread({
      int id = 14,
      required DateTime at,
      int senderId = them,
      int unread = 1,
      String text = 'Sabah saat 8-də görüşək?',
    }) => Conversation(
      id: id,
      bookingId: 88,
      rideId: 7,
      otherUser: const PublicUser(id: them, fullName: 'Rəşad Məmmədov'),
      lastMessage: text,
      lastMessageAt: at,
      lastSenderId: senderId,
      unreadCount: unread,
    );

    test('raises a notification, carrying who and what', () async {
      final first = DateTime(2026, 9, 19, 20);
      chat.conversations_ = [thread(at: first)];

      // First pass is the baseline: opening the app must not fire a banner for
      // every message that arrived while it was closed.
      watcher.start(userId: me);
      await pumpEventQueue();
      expect(seen, isEmpty, reason: 'baseline pass announces nothing');

      chat.conversations_ = [thread(at: first.add(const Duration(minutes: 1)))];
      await tick();

      expect(seen, hasLength(1));
      expect(seen.single.type, NotificationType.newMessage);
      expect(seen.single.conversationId, 14);
      expect(seen.single.actorName, 'Rəşad Məmmədov');
      expect(seen.single.body, 'Sabah saat 8-də görüşək?');
      expect(seen.single.channel, PushChannel.messages);
    });

    test('stays quiet for the thread the user is reading', () async {
      final first = DateTime(2026, 9, 19, 20);
      chat.conversations_ = [thread(at: first)];

      watcher.start(userId: me);
      await pumpEventQueue();

      // The chat screen sets this while it is on top.
      deepLink.openConversationId = 14;
      chat.conversations_ = [thread(at: first.add(const Duration(minutes: 1)))];
      await tick();

      expect(seen, isEmpty, reason: 'the message is already on screen');
    });

    test('stays quiet for the user\'s own message', () async {
      final first = DateTime(2026, 9, 19, 20);
      chat.conversations_ = [thread(at: first)];

      watcher.start(userId: me);
      await pumpEventQueue();

      chat.conversations_ = [
        thread(
          at: first.add(const Duration(minutes: 1)),
          senderId: me,
          unread: 0,
        ),
      ];
      await tick();

      expect(seen, isEmpty, reason: 'your own message is not news');
    });

    test('stays quiet once the thread is read elsewhere', () async {
      final first = DateTime(2026, 9, 19, 20);
      chat.conversations_ = [thread(at: first)];

      watcher.start(userId: me);
      await pumpEventQueue();

      // Read on another device: newer message, but nothing unread.
      chat.conversations_ = [
        thread(at: first.add(const Duration(minutes: 1)), unread: 0),
      ];
      await tick();

      expect(seen, isEmpty);
    });

    test('announces each new message once, not on every tick', () async {
      final first = DateTime(2026, 9, 19, 20);
      chat.conversations_ = [thread(at: first)];

      watcher.start(userId: me);
      await pumpEventQueue();

      chat.conversations_ = [thread(at: first.add(const Duration(minutes: 1)))];
      await tick();
      await tick();
      await tick();

      expect(seen, hasLength(1), reason: 'the timer must not repeat itself');
    });

    test('a failed read does not become the baseline', () async {
      // Otherwise the first message after a network blip is written off as
      // already seen and never announced.
      chat.fail = true;

      watcher.start(userId: me);
      await pumpEventQueue();

      chat
        ..fail = false
        ..conversations_ = [thread(at: DateTime(2026, 9, 19, 20))];
      await tick();
      expect(seen, isEmpty, reason: 'this is the first successful read');

      chat.conversations_ = [thread(at: DateTime(2026, 9, 19, 20, 1))];
      await tick();
      expect(seen, hasLength(1));
    });

    test('signing out clears the baseline for the next account', () async {
      final first = DateTime(2026, 9, 19, 20);
      chat.conversations_ = [thread(at: first)];

      watcher.start(userId: me);
      await pumpEventQueue();

      watcher.stop();
      expect(watcher.isRunning, isFalse);

      // A different user on the same device starts over, so nothing from the
      // previous account leaks into a banner.
      watcher.start(userId: 99);
      await pumpEventQueue();
      chat.conversations_ = [thread(at: first.add(const Duration(minutes: 1)))];
      await tick();

      expect(seen, hasLength(1), reason: 'baseline was rebuilt, not inherited');
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
  String? externalId;
  String? languageCode;

  @override
  String? get currentToken => _token;

  @override
  String get provider => 'fake';

  @override
  Future<bool> start() async => true;

  @override
  Future<void> identify({
    required String externalId,
    String? languageCode,
  }) async {
    this.externalId = externalId;
    this.languageCode = languageCode;
  }

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
    externalId = null;
  }

  @override
  Future<void> dispose() async {}
}

/// Serves a canned `GET /conversations` page, and can fail on demand.
class _FakeChatRepository implements ChatRepository {
  List<Conversation> conversations_ = const [];
  bool fail = false;

  @override
  FutureResult<Paginated<Conversation>> conversations({int? page}) async {
    if (fail) {
      return const Err(NetworkFailure(debugMessage: 'offline'));
    }
    return Ok(Paginated(items: conversations_, meta: PageMeta.single));
  }

  @override
  FutureResult<Paginated<ChatMessage>> messages(int id, {int? page}) =>
      throw UnimplementedError();

  @override
  FutureResult<ChatMessage> send(int id, String text) =>
      throw UnimplementedError();

  @override
  FutureResult<void> markRead(int id) async => const Ok(null);

  @override
  FutureResult<int> unreadTotal() async => const Ok(0);
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
