import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/core/error/result.dart';
import 'package:yolyoldasi/features/call/domain/entities/call.dart';
import 'package:yolyoldasi/features/call/domain/services/call_audio.dart';
import 'package:yolyoldasi/features/call/domain/services/system_call_ui.dart';
import 'package:yolyoldasi/features/call/presentation/bloc/call_bloc.dart';
import 'package:yolyoldasi/features/call/presentation/incoming/incoming_calls.dart';

import 'support/call_fakes.dart';

/// The calls that ring on this phone: what the app does with each thing the
/// user does on the system call screen.
void main() {
  late FakeCallRepository calls;
  late FakeCallAudio audio;
  late FakeSystemCallUi system;

  const call = IncomingCall(
    uuid: '6f1c2a3e-0000-4000-8000-000000000042',
    callId: 42,
    caller: CallPeer(userId: 7, name: 'Sərnişin'),
  );

  setUp(() {
    calls = FakeCallRepository();
    audio = FakeCallAudio();
    system = FakeSystemCallUi();
    addTearDown(audio.dispose);
    addTearDown(system.dispose);
  });

  IncomingCalls build() {
    final incoming = IncomingCalls(
      calls: calls,
      system: system,
      createBloc: () =>
          CallBloc(calls: calls, audio: audio, microphone: () async => true),
      statusPollInterval: const Duration(milliseconds: 10),
      lingerAfterEnd: const Duration(milliseconds: 10),
    );
    addTearDown(incoming.dispose);
    return incoming;
  }

  Future<void> reach(CallBloc bloc, CallPhase phase) async {
    if (bloc.state.phase == phase) return;
    await bloc.stream.firstWhere((s) => s.phase == phase);
  }

  test('answering on the system screen runs the call, starts its clock, and '
      'hanging up there ends it on the API', () async {
    final incoming = build();
    await incoming.start();

    system.controller.add(const SystemCallAccepted(call));
    await settle();
    final bloc = incoming.active!.bloc;
    await reach(bloc, CallPhase.ringing);
    expect(calls.accepted, [42]);

    audio.controller.add(const CallAudioPeerJoined(7));
    await reach(bloc, CallPhase.active);
    await settle();
    expect(system.connected, [call.uuid]);

    system.controller.add(SystemCallEnded(call.uuid));
    await reach(bloc, CallPhase.ended);
    await settle();

    expect(calls.ended, [42]);
    expect(system.endedOnScreen, contains(call.uuid));

    // "Call ended" stays up for a moment, then the app's screen goes away.
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(incoming.active, isNull);
  });

  test('declining on the system screen declines on the API', () async {
    final incoming = build();
    await incoming.start();

    system.controller.add(const SystemCallDeclined(call));
    await settle();

    expect(calls.rejected, [42]);
    expect(incoming.active, isNull);
  });

  test('stops ringing when the caller gives up, without calling that a '
      'decline', () async {
    final incoming = build();
    await incoming.start();
    system.controller.add(const SystemCallRinging(call));
    await settle();

    calls.statusResult = const Ok(CallStatus.missed);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(system.endedOnScreen, [call.uuid]);

    // CallKit reports a call the app took off the screen as declined.
    system.controller.add(const SystemCallDeclined(call));
    await settle();
    expect(calls.rejected, isEmpty);
  });

  test('keeps ringing while the call is still ringing on the API', () async {
    final incoming = build();
    await incoming.start();
    system.controller.add(const SystemCallRinging(call));

    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(calls.statusAsked, isNotEmpty);
    expect(system.endedOnScreen, isEmpty);
  });

  test('an answer given before the app was listening is picked up at launch, '
      'once', () async {
    system.active = [(call: call, accepted: true)];
    final incoming = build();
    await incoming.start();
    await settle();
    expect(incoming.active?.call, call);

    // The same answer, arriving late as an event.
    system.controller.add(const SystemCallAccepted(call));
    await settle();

    expect(calls.accepted, [42]);
  });

  test(
    'mute travels both ways between the system screen and the call',
    () async {
      final incoming = build();
      await incoming.start();
      system.controller.add(const SystemCallAccepted(call));
      await settle();
      final bloc = incoming.active!.bloc;
      await reach(bloc, CallPhase.ringing);

      system.controller.add(SystemCallMuteChanged(call.uuid, muted: true));
      await settle();
      expect(bloc.state.muted, isTrue);
      expect(audio.muted, [true]);

      bloc.add(const CallMuteToggled());
      await settle();
      expect(system.mutes.last, (call.uuid, false));
    },
  );
}
