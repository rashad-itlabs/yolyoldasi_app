import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/features/call/data/services/callkit_service.dart';
import 'package:yolyoldasi/features/call/domain/entities/call.dart';
import 'package:yolyoldasi/features/call/domain/services/system_call_ui.dart';

import 'support/call_fakes.dart';

/// The bridge from CallKit's events to the app, against the plugin's real
/// event channel with the native side mocked.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = EventChannel('flutter_callkit_incoming_events');
  const uuid = '6f1c2a3e-0000-4000-8000-000000000042';
  late MockStreamHandlerEventSink native;
  var listens = 0;

  setUp(() {
    listens = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          channel,
          MockStreamHandler.inline(
            onListen: (arguments, events) {
              listens++;
              native = events;
            },
          ),
        );
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(channel, null),
  );

  /// What the plugin sends when the user picks up: the call's data, with the
  /// VoIP push's fields in `extra` (see AppDelegate.swift).
  Map<String, Object?> answered({Object? callId = 42}) => {
    'event': 'com.hiennv.flutter_callkit_incoming.ACTION_CALL_ACCEPT',
    'body': {
      'id': uuid,
      'nameCaller': 'Togrul Qasimov',
      'extra': {
        'call_id': callId,
        'caller_id': 7,
        'caller_name': 'Togrul Qasimov',
        'caller_photo': '',
      },
    },
  };

  test(
    'every listener hears an answer, not just the last to subscribe',
    () async {
      // The real app has two: IncomingCalls, started in main, and AppStartup,
      // listening for VoIP tokens once the first frame is up. With one stream
      // each, the second took the channel and the answered call went nowhere.
      final service = CallKitService();
      final calls = <SystemCallEvent>[];
      final tokens = <SystemCallEvent>[];

      final first = service.events.listen(calls.add);
      await settle();
      final second = service.events.listen(tokens.add);
      await settle();

      native.success(answered());
      await settle();

      expect(listens, 1, reason: 'one platform subscription, shared');
      expect(calls, hasLength(1));
      expect(tokens, hasLength(1));

      await first.cancel();
      await second.cancel();
    },
  );

  test('reads the call and the caller out of the push fields', () async {
    final service = CallKitService();
    final events = <SystemCallEvent>[];
    final subscription = service.events.listen(events.add);
    await settle();

    native.success(answered());
    await settle();

    final accepted = events.single as SystemCallAccepted;
    expect(
      accepted.call,
      const IncomingCall(
        uuid: uuid,
        callId: 42,
        caller: CallPeer(userId: 7, name: 'Togrul Qasimov'),
      ),
    );

    await subscription.cancel();
  });

  test('ignores a call that carries no call id', () async {
    final service = CallKitService();
    final events = <SystemCallEvent>[];
    final subscription = service.events.listen(events.add);
    await settle();

    native.success(answered(callId: 0));
    await settle();

    expect(events, isEmpty);
    await subscription.cancel();
  });
}
