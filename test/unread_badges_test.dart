import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yolyoldasi/app/app_startup.dart';
import 'package:yolyoldasi/core/di/app_dependencies.dart';
import 'package:yolyoldasi/core/network/api_client.dart';
import 'package:yolyoldasi/core/services/app_version_info.dart';
import 'package:yolyoldasi/core/services/push/local_notifications.dart';
import 'package:yolyoldasi/core/services/push/push_message.dart';
import 'package:yolyoldasi/core/services/push/push_service.dart';
import 'package:yolyoldasi/core/services/token_storage.dart';
import 'package:yolyoldasi/features/auth/presentation/bloc/session/session_bloc.dart';
import 'package:yolyoldasi/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:yolyoldasi/features/chat/data/services/chat_api_service.dart';
import 'package:yolyoldasi/features/chat/presentation/bloc/chat/chat_bloc.dart';
import 'package:yolyoldasi/features/chat/presentation/bloc/conversations/conversations_bloc.dart';
import 'package:yolyoldasi/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:yolyoldasi/features/notifications/data/services/notification_api_service.dart';
import 'package:yolyoldasi/features/notifications/presentation/bloc/notifications/notifications_bloc.dart';
import 'package:yolyoldasi/features/shell/presentation/bloc/badges/badges_bloc.dart';

/// The two counters in the navigation bar, and the bell in particular.
///
/// Reported as: "opening a chat marks the messages read, but the number on
/// the notifications does not go down." Every chat message also leaves a
/// `newMessage` notification, and the bell counts those. The server now marks
/// them read with the thread (API.md §11); these are the app's half — the
/// badges have to be re-read once that call has landed, from whichever screen
/// the thread was opened, and a push must raise the counters rather than reset
/// them.
///
/// Everything below runs the real repositories and API services against a
/// stubbed server, so the thing under test is the actual wiring rather than a
/// fake's idea of it.
void main() {
  group('reading a thread', () {
    late _Server server;
    late ChatRepositoryImpl chat;
    late BadgesBloc badges;

    setUp(() {
      server = _Server()
        ..unreadMessages = 3
        ..unreadNotifications = 5;
      final client = server.client();
      chat = ChatRepositoryImpl(ChatApiService(client));
      badges = BadgesBloc(
        chat: chat,
        notifications: NotificationRepositoryImpl(
          NotificationApiService(client),
        ),
      );
      addTearDown(badges.close);
    });

    Future<void> loaded() async {
      badges.add(const BadgesRefreshed());
      await _until(() => badges.state == _counts(3, 5));
    }

    test('lowers the bell as well as the message badge', () async {
      await loaded();

      // What `ChatPage` does: the bloc loads the thread and marks it read.
      // Nothing else is dispatched — no screen tells the badges anything.
      final thread = ChatBloc(chat: chat, conversationId: 14)
        ..add(const ChatStarted());
      addTearDown(thread.close);

      await _until(() => badges.state == _counts(0, 2));
      expect(server.count('POST /conversations/14/read'), 1);
    });

    test(
      'still lowers it when the screen is closed before the call returns',
      () async {
        // Backing out of a thread straight away used to leave the bell stale:
        // the re-read on the way back could reach the server before the read.
        await loaded();
        final hold = server.holdNext('POST /conversations/14/read');

        final thread = ChatBloc(chat: chat, conversationId: 14)
          ..add(const ChatStarted());
        await _until(() => server.count('POST /conversations/14/read') == 1);
        await thread.close();

        hold.complete();
        await _until(() => badges.state == _counts(0, 2));
      },
    );

    test('that failed leaves both badges where they were', () async {
      await loaded();
      server.failWrites = true;

      final thread = ChatBloc(chat: chat, conversationId: 14)
        ..add(const ChatStarted());
      addTearDown(thread.close);

      await _until(() => server.count('POST /conversations/14/read') == 1);
      await pumpEventQueue(times: 200);

      expect(
        server.count('GET /notifications/unread-count'),
        1,
        reason: 'nothing changed on the server, so nothing is re-read',
      );
      expect(badges.state, _counts(3, 5));
    });

    test('is not lost behind a refresh already in flight', () async {
      // A push tap asks for the badges as it opens the thread, and that read
      // is still out when the thread is marked read. The old `droppable()`
      // kept the stale answer and discarded the fresh request.
      final stale = server.holdNext('GET /notifications/unread-count');
      badges.add(const BadgesRefreshed());
      await _until(() => server.count('GET /notifications/unread-count') == 1);

      await chat.markRead(14);
      await _until(() => badges.state == _counts(0, 2));

      // The first read now answers with the counts from before.
      stale.complete();
      await pumpEventQueue(times: 50);
      expect(badges.state, _counts(0, 2));
    });
  });

  group('reading a notification', () {
    late _Server server;
    late NotificationRepositoryImpl notifications;
    late BadgesBloc badges;

    setUp(() async {
      server = _Server()
        ..unreadMessages = 1
        ..unreadNotifications = 5;
      final client = server.client();
      notifications = NotificationRepositoryImpl(
        NotificationApiService(client),
      );
      badges = BadgesBloc(
        chat: ChatRepositoryImpl(ChatApiService(client)),
        notifications: notifications,
      );
      addTearDown(badges.close);

      badges.add(const BadgesRefreshed());
      await _until(() => badges.state == _counts(1, 5));
    });

    test('re-reads the bell once the write has landed', () async {
      // The page used to ask in the same breath as the write, and the count
      // that won the race came back unchanged.
      await notifications.markRead(120);
      await _until(() => badges.state.unreadNotifications == 4);

      await notifications.markAllRead();
      await _until(() => badges.state.unreadNotifications == 0);
      expect(badges.state.unreadMessages, 1);
    });

    test('that failed leaves the bell alone', () async {
      server.failWrites = true;

      await notifications.markRead(120);
      await pumpEventQueue(times: 200);

      expect(server.count('GET /notifications/unread-count'), 1);
      expect(badges.state, _counts(1, 5));
    });
  });

  group('screens that outlive the thread', () {
    late _Server server;
    late ChatRepositoryImpl chat;

    setUp(() {
      server = _Server()
        ..conversations = [_thread(14, unread: 3), _thread(15, unread: 1)]
        ..notifications = [
          _row(1, 'newMessage', conversationId: 14),
          _row(2, 'newMessage', conversationId: 14),
          _row(3, 'newMessage', conversationId: 15),
          _row(4, 'bookingConfirmed', bookingId: 88),
        ];
      chat = ChatRepositoryImpl(ChatApiService(server.client()));
    });

    test(
      'the notification centre marks that thread\'s chat rows read',
      () async {
        // Tapping one chat row opens the thread over this list, and the list is
        // not reloaded on the way back. The server has marked *all* of that
        // thread's rows read; the others must not keep looking unread.
        final bloc = NotificationsBloc(
          notifications: NotificationRepositoryImpl(
            NotificationApiService(server.client()),
          ),
          chat: chat,
        )..add(const NotificationsRequested());
        addTearDown(bloc.close);
        await _until(() => bloc.state.notifications.length == 4);

        await chat.markRead(14);
        await _until(() => bloc.state.unreadCount == 2);

        final read = {for (final n in bloc.state.notifications) n.id: n.isRead};
        expect(read, {1: true, 2: true, 3: false, 4: false});
      },
    );

    test(
      'the notification centre keeps them unread if the read failed',
      () async {
        final bloc = NotificationsBloc(
          notifications: NotificationRepositoryImpl(
            NotificationApiService(server.client()),
          ),
          chat: chat,
        )..add(const NotificationsRequested());
        addTearDown(bloc.close);
        await _until(() => bloc.state.notifications.length == 4);

        server.failWrites = true;
        await chat.markRead(14);
        await pumpEventQueue(times: 50);

        expect(bloc.state.unreadCount, 4);
      },
    );

    test('the conversation list zeroes the row, only on success', () async {
      // The row used to be zeroed on coming back from the thread, whether or
      // not the server had taken the read.
      final list = ConversationsBloc(chat: chat)
        ..add(const ConversationsRequested());
      addTearDown(list.close);
      await _until(() => list.state.conversations.length == 2);

      Map<int, int> unread() => {
        for (final c in list.state.conversations) c.id: c.unreadCount,
      };

      server.failWrites = true;
      await chat.markRead(14);
      await pumpEventQueue(times: 50);
      expect(unread(), {14: 3, 15: 1});

      server.failWrites = false;
      await chat.markRead(14);
      await _until(() => unread()[14] == 0);
      expect(unread(), {14: 0, 15: 1});
    });
  });

  group('a push while the app is open', () {
    // `AppStartup._onForeground`. It used to dispatch `MessageBadgeAdjusted(1)`
    // or `NotificationBadgeAdjusted(1)` — events that *set* the total — so any
    // push reset a counter to 1, and a chat push never touched the bell even
    // though the server had added a notification row for it.
    late _Server server;
    late _FakePush push;
    late AppDependencies dependencies;
    late BadgesBloc badges;

    /// Built inside the test body, not in `setUp`: a bloc created outside the
    /// widget test's fake clock handles its events on the real one, which does
    /// not advance while the test pumps.
    Future<void> pumpApp(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      server = _Server()
        ..unreadMessages = 5
        ..unreadNotifications = 7;
      push = _FakePush();
      final tokens = InMemoryTokenStorage();
      dependencies = await AppDependencies.bootstrap(
        preferences: await SharedPreferences.getInstance(),
        apiClient: server.client(tokens: tokens),
        tokenStorage: tokens,
        push: push,
        localNotifications: LocalNotifications(plugin: _Plugin()),
        version: AppVersionInfo.unknown,
      );
      badges = BadgesBloc(
        chat: dependencies.chat,
        notifications: dependencies.notifications,
      );

      final session = _MockSessionBloc();
      whenListen(
        session,
        const Stream<SessionState>.empty(),
        initialState: const SessionState(),
      );

      await tester.pumpWidget(
        RepositoryProvider<AppDependencies>.value(
          value: dependencies,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<SessionBloc>.value(value: session),
              BlocProvider<BadgesBloc>.value(value: badges),
            ],
            child: const AppStartup(child: SizedBox()),
          ),
        ),
      );

      badges.add(const BadgesRefreshed());
      await _settle(tester);
      expect(badges.state, _counts(5, 7));
    }

    Future<void> tearDownApp(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      // `AppStartup` logs `app_open`, which arms a 30-second flush timer. The
      // flush cancels it before it sends.
      unawaited(dependencies.analytics.flush());
      // Not awaited: closing waits on work the fake clock only runs when
      // pumped, so awaiting it here would never return.
      unawaited(badges.close());
      await _settle(tester);
    }

    testWidgets('a chat message raises both counters, not resets them', (
      tester,
    ) async {
      await pumpApp(tester);

      // What the server holds once the message is in: one more unread
      // message, and one more notification row.
      server
        ..unreadMessages = 6
        ..unreadNotifications = 8;
      push.deliver({'type': 'newMessage', 'conversation_id': '14'});
      await _settle(tester);

      expect(badges.state, _counts(6, 8));
      await tearDownApp(tester);
    });

    testWidgets('any other push raises the bell, not resets it', (
      tester,
    ) async {
      await pumpApp(tester);

      server.unreadNotifications = 8;
      push.deliver({'type': 'bookingConfirmed', 'booking_id': '88'});
      await _settle(tester);

      expect(badges.state, _counts(5, 8));
      await tearDownApp(tester);
    });

    testWidgets(
      'a message for the thread on screen still re-reads the badges',
      (tester) async {
        // The screen's poll marks it read within a tick and lowers them again.
        // Leaving it to that poll alone left both badges one short whenever the
        // user backed out before the tick came.
        await pumpApp(tester);
        dependencies.pendingDeepLink.openConversationId = 14;
        final before = server.count('GET /notifications/unread-count');

        server
          ..unreadMessages = 6
          ..unreadNotifications = 8;
        push.deliver({'type': 'newMessage', 'conversation_id': '14'});
        await _settle(tester);

        expect(server.count('GET /notifications/unread-count'), before + 1);
        expect(badges.state, _counts(6, 8));

        await tearDownApp(tester);
      },
    );
  });
}

/// Messages first, then the bell — the order the shell shows them in.
BadgesState _counts(int messages, int notifications) =>
    BadgesState(unreadMessages: messages, unreadNotifications: notifications);

/// Polls [condition] until it holds, failing the test rather than hanging if
/// it never does.
Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 400; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('condition never became true');
}

/// Lets a push travel the stream, the bloc and the stubbed HTTP round trip.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

Map<String, dynamic> _thread(int id, {required int unread}) => {
  'id': id,
  'booking_id': 80 + id,
  'ride_id': 7,
  'last_message': 'Saat 8-də görüşürük.',
  'last_message_at': '2026-09-26T12:00:00+04:00',
  'last_sender_id': 99,
  'is_locked': false,
  'other_user': {'id': 99, 'full_name': 'Rəşad Məmmədov'},
  'unread_count': unread,
};

Map<String, dynamic> _row(
  int id,
  String type, {
  int? conversationId,
  int? bookingId,
}) => {
  'id': id,
  'type': type,
  'ride_id': 7,
  'booking_id': bookingId ?? 88,
  'conversation_id': conversationId,
  'actor': null,
  'payload': <String, dynamic>{},
  'read_at': null,
  'created_at': '2026-09-26T12:00:00+04:00',
};

/// Enough of the API for the badges: the two counts, the reads that change
/// them, and the lists that show them. A thread read does what the server now
/// does — zeroes the thread's messages and marks its `newMessage` rows read.
class _Server implements HttpClientAdapter {
  int unreadMessages = 0;
  int unreadNotifications = 0;
  List<Map<String, dynamic>> conversations = const [];
  List<Map<String, dynamic>> notifications = const [];

  /// Every write answers 500 while this is set.
  bool failWrites = false;

  final List<String> calls = [];
  final Map<String, Completer<void>> _holds = {};

  ApiClient client({TokenStorage? tokens}) => ApiClient(
    tokens: tokens ?? InMemoryTokenStorage(),
    dio: Dio()..httpClientAdapter = this,
    baseUrl: 'https://example.test/api/v1',
  );

  int count(String route) => calls.where((call) => call == route).length;

  /// Delays the next answer to [route] until the returned completer is
  /// completed. The answer itself is decided when the request arrives, as a
  /// real server would, so a held read carries the counts of that moment.
  Completer<void> holdNext(String route) => _holds[route] = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final route = '${options.method} ${options.path}';
    calls.add(route);

    final hold = _holds.remove(route);
    final (status, body) = _answer(route, commit: hold == null);
    if (hold != null) {
      await hold.future;
      // A held write takes effect when it is let through.
      _answer(route, commit: true);
    }

    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  (int, Object) _answer(String route, {required bool commit}) {
    final isWrite = route.startsWith('POST ') && route != 'POST /events';
    if (isWrite && failWrites) return (500, {'message': 'Server Error'});

    switch (route) {
      case 'GET /conversations/unread-count':
        return (200, {'unread_total': unreadMessages});
      case 'GET /notifications/unread-count':
        return (200, {'unread_total': unreadNotifications});
      case 'GET /conversations':
        return (200, {'data': conversations});
      case 'GET /notifications':
        return (200, {'data': notifications});
      case 'GET /conversations/14/messages':
        return (200, {'data': <Object>[]});
      case 'POST /conversations/14/read':
        if (commit) {
          unreadMessages = 0;
          unreadNotifications = 2;
        }
        return (200, {'message': 'ok'});
      case 'POST /notifications/read-all':
        if (commit) unreadNotifications = 0;
        return (200, {'message': 'ok'});
    }
    if (route.startsWith('POST /notifications/') && route.endsWith('/read')) {
      if (commit) unreadNotifications -= 1;
      return (200, {'message': 'ok'});
    }
    return (200, <String, Object>{});
  }

  @override
  void close({bool force = false}) {}
}

/// A push transport whose foreground messages the test delivers by hand.
class _FakePush implements PushService {
  final StreamController<PushMessage> _foreground =
      StreamController<PushMessage>.broadcast();

  void deliver(Map<String, dynamic> data) =>
      _foreground.add(PushMessage.fromData(data));

  @override
  Stream<PushMessage> get foregroundMessages => _foreground.stream;

  @override
  Stream<PushMessage> get taps => const Stream<PushMessage>.empty();

  @override
  Stream<String> get tokenChanges => const Stream<String>.empty();

  @override
  String? get currentToken => null;

  @override
  String get provider => 'fake';

  @override
  Future<bool> start() async => true;

  @override
  Future<void> identify({
    required String externalId,
    String? languageCode,
  }) async {}

  @override
  Future<void> clear() async {}

  @override
  Future<void> dispose() => _foreground.close();
}

/// Never reached: [LocalNotifications] draws nothing until it is initialized,
/// which only happens on sign-in.
class _Plugin extends Mock implements FlutterLocalNotificationsPlugin {}

class _MockSessionBloc extends MockBloc<SessionEvent, SessionState>
    implements SessionBloc {}
