import 'dart:async';

import 'package:yolyoldasi/core/error/result.dart';
import 'package:yolyoldasi/features/call/domain/entities/call.dart';
import 'package:yolyoldasi/features/call/domain/repositories/call_repository.dart';
import 'package:yolyoldasi/features/call/domain/services/call_audio.dart';
import 'package:yolyoldasi/features/call/domain/services/system_call_ui.dart';

const testCall = Call(
  id: 42,
  callerId: 7,
  receiverId: 9,
  channelName: 'call_test',
);

const testCredentials = CallCredentials(
  appId: 'app',
  channelName: 'call_test',
  uid: 7,
  token: 'token',
);

/// Records every call the bloc makes against the API.
class FakeCallRepository implements CallRepository {
  Result<Call> createResult = const Ok(testCall);
  Result<CallCredentials> credentialsResult = const Ok(testCredentials);
  Result<void> acceptResult = const Ok(null);
  Result<CallStatus> statusResult = const Ok(CallStatus.ringing);

  /// When set, `create` waits on it — a slow API.
  Completer<void>? createGate;

  /// When set, `accept` waits on it.
  Completer<void>? acceptGate;

  int created = 0;
  final accepted = <int>[];
  final rejected = <int>[];
  final ended = <int>[];
  final statusAsked = <int>[];
  final voipTokens = <String>[];

  @override
  FutureResult<Call> create(int receiverId) async {
    created++;
    await createGate?.future;
    return createResult;
  }

  @override
  FutureResult<CallStatus> status(int callId) async {
    statusAsked.add(callId);
    return statusResult;
  }

  @override
  FutureResult<CallCredentials> credentials(int callId) async =>
      credentialsResult;

  @override
  FutureResult<void> accept(int callId) async {
    accepted.add(callId);
    await acceptGate?.future;
    return acceptResult;
  }

  @override
  FutureResult<void> reject(int callId) async {
    rejected.add(callId);
    return const Ok(null);
  }

  @override
  FutureResult<void> end(int callId) async {
    ended.add(callId);
    return const Ok(null);
  }

  @override
  FutureResult<void> registerVoipToken(String token) async {
    voipTokens.add(token);
    return const Ok(null);
  }
}

class FakeCallAudio implements CallAudio {
  final controller = StreamController<CallAudioEvent>.broadcast();
  Result<void> joinResult = const Ok(null);

  final joined = <CallCredentials>[];
  final muted = <bool>[];
  int leaves = 0;

  @override
  Stream<CallAudioEvent> get events => controller.stream;

  @override
  FutureResult<void> join(CallCredentials credentials) async {
    joined.add(credentials);
    return joinResult;
  }

  @override
  Future<void> leave() async => leaves++;

  @override
  Future<void> setMuted(bool value) async => muted.add(value);

  @override
  Future<void> setSpeakerphone(bool enabled) async {}

  Future<void> dispose() => controller.close();
}

/// CallKit, as far as the coordinator can tell.
class FakeSystemCallUi implements SystemCallUi {
  final controller = StreamController<SystemCallEvent>.broadcast();
  List<({IncomingCall call, bool accepted})> active = const [];
  String? token;

  final connected = <String>[];
  final endedOnScreen = <String>[];
  final mutes = <(String, bool)>[];

  @override
  Stream<SystemCallEvent> get events => controller.stream;

  @override
  Future<String?> voipToken() async => token;

  @override
  Future<List<({IncomingCall call, bool accepted})>> activeCalls() async =>
      active;

  @override
  Future<void> reportConnected(String uuid) async => connected.add(uuid);

  @override
  Future<void> reportEnded(String uuid) async => endedOnScreen.add(uuid);

  @override
  Future<void> setMuted(String uuid, bool muted) async =>
      mutes.add((uuid, muted));

  Future<void> dispose() => controller.close();
}

/// Lets handlers run to their next await.
Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
