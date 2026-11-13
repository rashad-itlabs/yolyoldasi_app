import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/core/error/failure.dart';
import 'package:yolyoldasi/core/error/result.dart';
import 'package:yolyoldasi/features/call/domain/entities/call.dart';
import 'package:yolyoldasi/features/call/domain/services/call_audio.dart';
import 'package:yolyoldasi/features/call/presentation/bloc/call_bloc.dart';

import 'support/call_fakes.dart';

void main() {
  late FakeCallRepository calls;
  late FakeCallAudio audio;
  final connectedAt = DateTime(2026, 11, 13, 10);

  setUp(() {
    calls = FakeCallRepository();
    audio = FakeCallAudio();
    addTearDown(audio.dispose);
  });

  CallBloc build({
    bool microphone = true,
    Duration ringTimeout = const Duration(minutes: 1),
    Duration connectTimeout = const Duration(minutes: 1),
    Duration statusPollInterval = const Duration(minutes: 1),
  }) {
    final bloc = CallBloc(
      calls: calls,
      audio: audio,
      microphone: () async => microphone,
      ringTimeout: ringTimeout,
      connectTimeout: connectTimeout,
      statusPollInterval: statusPollInterval,
      clock: () => connectedAt,
    );
    addTearDown(bloc.close);
    return bloc;
  }

  Future<CallState> reach(CallBloc bloc, CallPhase phase) async {
    if (bloc.state.phase == phase) return bloc.state;
    return bloc.stream.firstWhere((s) => s.phase == phase);
  }

  group('calling out', () {
    test('rings, connects when the other person joins, and hangs up '
        'everywhere', () async {
      final bloc = build()..add(const CallStarted(9));

      await reach(bloc, CallPhase.ringing);
      expect(audio.joined, [testCredentials]);

      audio.controller.add(const CallAudioPeerJoined(9));
      final active = await reach(bloc, CallPhase.active);
      expect(active.connectedAt, connectedAt);

      bloc.add(const CallHungUp());
      final ended = await reach(bloc, CallPhase.ended);
      await settle();

      expect(ended.endReason, CallEndReason.hungUp);
      expect(audio.leaves, 1);
      expect(calls.ended, [42]);
      expect(calls.rejected, isEmpty);
    });

    test(
      'a refused microphone ends the call before the API hears of it',
      () async {
        final bloc = build(microphone: false)..add(const CallStarted(9));

        final ended = await reach(bloc, CallPhase.ended);

        expect(ended.endReason, CallEndReason.microphoneDenied);
        expect(calls.created, 0);
        expect(audio.joined, isEmpty);
      },
    );

    test(
      'an API refusal ends the call with its message and joins nothing',
      () async {
        const refusal = BusinessFailure(
          FailureCode.invalidInput,
          serverMessage: 'Özünüzə zəng edə bilməzsiniz.',
        );
        calls.createResult = const Err(refusal);
        final bloc = build()..add(const CallStarted(9));

        final ended = await reach(bloc, CallPhase.ended);
        await settle();

        expect(ended.endReason, CallEndReason.failed);
        expect(ended.failure, refusal);
        expect(audio.joined, isEmpty);
        // Nothing was created, so there is nothing to end.
        expect(calls.ended, isEmpty);
      },
    );

    test('an Agora join error is a failed call, ended on the API', () async {
      audio.joinResult = const Err(UnknownFailure(debugMessage: 'agora -2'));
      final bloc = build()..add(const CallStarted(9));

      final ended = await reach(bloc, CallPhase.ended);
      await settle();

      expect(ended.endReason, CallEndReason.failed);
      expect(calls.ended, [42]);
    });

    test('stops ringing when nobody answers in time', () async {
      final bloc = build(ringTimeout: const Duration(milliseconds: 20))
        ..add(const CallStarted(9));

      final ended = await reach(bloc, CallPhase.ended);
      await settle();

      expect(ended.endReason, CallEndReason.noAnswer);
      expect(audio.leaves, 1);
      expect(calls.ended, [42]);
    });

    test('learns of a decline by asking, since nothing pushes it', () async {
      final bloc = build(statusPollInterval: const Duration(milliseconds: 10))
        ..add(const CallStarted(9));
      await reach(bloc, CallPhase.ringing);

      calls.statusResult = const Ok(CallStatus.rejected);
      final ended = await reach(bloc, CallPhase.ended);
      await settle();

      expect(ended.endReason, CallEndReason.rejected);
      expect(calls.statusAsked, everyElement(42));
      expect(audio.leaves, 1);
    });

    test('stops asking once the other person is on the line', () async {
      final bloc = build(statusPollInterval: const Duration(milliseconds: 10))
        ..add(const CallStarted(9));
      await reach(bloc, CallPhase.ringing);
      audio.controller.add(const CallAudioPeerJoined(9));
      await reach(bloc, CallPhase.active);
      final asked = calls.statusAsked.length;

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(calls.statusAsked.length, asked);
    });

    test('the other person hanging up ends the call', () async {
      final bloc = build()..add(const CallStarted(9));
      await reach(bloc, CallPhase.ringing);
      audio.controller.add(const CallAudioPeerJoined(9));
      await reach(bloc, CallPhase.active);

      audio.controller.add(const CallAudioPeerLeft(9));
      final ended = await reach(bloc, CallPhase.ended);
      await settle();

      expect(ended.endReason, CallEndReason.peerLeft);
      expect(calls.ended, [42]);
    });

    test('hanging up while the API is still creating the call cancels it '
        'once the API answers', () async {
      calls.createGate = Completer<void>();
      final bloc = build()..add(const CallStarted(9));
      await settle();
      expect(bloc.state.phase, CallPhase.dialing);

      bloc.add(const CallHungUp());
      await reach(bloc, CallPhase.ended);
      // No id yet, so there was nothing to end.
      expect(calls.ended, isEmpty);

      calls.createGate!.complete();
      await settle();

      expect(calls.ended, [42]);
      // And the microphone never went into the channel.
      expect(audio.joined, isEmpty);
    });

    test('closing the screen mid-call hangs up instead of leaving the '
        'microphone live', () async {
      final bloc = build()..add(const CallStarted(9));
      await reach(bloc, CallPhase.ringing);

      await bloc.close();

      expect(audio.leaves, 1);
      expect(calls.ended, [42]);
    });

    test('closing the screen while the API is creating the call still '
        'cancels it', () async {
      calls.createGate = Completer<void>();
      final bloc = build()..add(const CallStarted(9));
      await settle();

      await bloc.close();
      calls.createGate!.complete();
      await settle();

      expect(calls.ended, [42]);
      expect(audio.joined, isEmpty);
    });

    test('mute only works once the microphone is live', () async {
      calls.createGate = Completer<void>();
      final bloc = build()..add(const CallStarted(9));
      await settle();

      bloc.add(const CallMuteToggled());
      await settle();
      expect(bloc.state.muted, isFalse);

      calls.createGate!.complete();
      await reach(bloc, CallPhase.ringing);
      bloc.add(const CallMuteToggled());
      await settle();

      expect(bloc.state.muted, isTrue);
      expect(audio.muted, [true]);

      // Set from the system screen to what it already is: nothing to do.
      bloc.add(const CallMuteSet(muted: true));
      await settle();
      expect(audio.muted, [true]);
    });
  });

  group('answering', () {
    test('accepts, joins the channel and connects when the caller is '
        'heard', () async {
      final bloc = build()..add(const CallAnswered(42));

      final waiting = await reach(bloc, CallPhase.ringing);
      expect(waiting.incoming, isTrue);
      expect(calls.accepted, [42]);
      expect(audio.joined, [testCredentials]);
      expect(calls.created, 0);

      audio.controller.add(const CallAudioPeerJoined(7));
      await reach(bloc, CallPhase.active);

      bloc.add(const CallHungUp());
      await reach(bloc, CallPhase.ended);
      await settle();

      // Accepted, so hanging up ends it rather than declining it.
      expect(calls.ended, [42]);
      expect(calls.rejected, isEmpty);
    });

    test('hanging up before the accept lands declines, then ends what the '
        'accept opened', () async {
      calls.acceptGate = Completer<void>();
      final bloc = build()..add(const CallAnswered(42));
      await settle();

      bloc.add(const CallHungUp());
      await reach(bloc, CallPhase.ended);
      await settle();
      expect(calls.rejected, [42]);

      calls.acceptGate!.complete();
      await settle();

      expect(calls.ended, [42]);
      expect(audio.joined, isEmpty);
    });

    test('a call that stopped ringing cannot be answered', () async {
      const gone = BusinessFailure(
        FailureCode.invalidInput,
        serverMessage: 'Zəng artıq aktiv deyil.',
      );
      calls.acceptResult = const Err(gone);
      final bloc = build()..add(const CallAnswered(42));

      final ended = await reach(bloc, CallPhase.ended);
      await settle();

      expect(ended.endReason, CallEndReason.failed);
      expect(ended.failure, gone);
      expect(audio.joined, isEmpty);
    });

    test('gives up if the caller never shows up in the channel', () async {
      final bloc = build(connectTimeout: const Duration(milliseconds: 20))
        ..add(const CallAnswered(42));

      final ended = await reach(bloc, CallPhase.ended);
      await settle();

      expect(ended.endReason, CallEndReason.failed);
      expect(calls.ended, [42]);
      // An answered call is not asked about: the caller's audio is the answer.
      expect(calls.statusAsked, isEmpty);
    });
  });
}
