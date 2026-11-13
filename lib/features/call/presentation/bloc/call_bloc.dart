import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/call.dart';
import '../../domain/repositories/call_repository.dart';
import '../../domain/services/call_audio.dart';

part 'call_event.dart';
part 'call_state.dart';

/// Asks for the microphone; `true` when it may be used.
typedef MicrophonePermission = Future<bool> Function();

Future<bool> _requestMicrophone() async =>
    (await Permission.microphone.request()).isGranted;

/// One voice call, from dialing or answering to hanging up.
///
/// Closing the bloc hangs up. An outgoing call's bloc lives exactly as long as
/// its screen, so the call cannot outlive what shows it; an answered call's
/// bloc is held by `IncomingCalls` for as long as the phone's own call screen
/// shows the call.
///
/// Handlers run concurrently, so a hang-up can land while [CallStarted] or
/// [CallAnswered] is still waiting on the API or the SDK. They check after
/// every await and undo whatever they set up in the meantime.
class CallBloc extends Bloc<CallEvent, CallState> {
  CallBloc({
    required CallRepository calls,
    required CallAudio audio,
    MicrophonePermission? microphone,
    this.ringTimeout = defaultRingTimeout,
    this.connectTimeout = defaultConnectTimeout,
    this.statusPollInterval = defaultStatusPollInterval,
    DateTime Function()? clock,
  }) : _calls = calls,
       _audio = audio,
       _microphone = microphone ?? _requestMicrophone,
       _clock = clock ?? DateTime.now,
       super(const CallState()) {
    on<CallStarted>(_onStarted);
    on<CallAnswered>(_onAnswered);
    on<CallHungUp>(_onHungUp);
    on<CallMuteToggled>((event, emit) => _setMuted(emit, muted: !state.muted));
    on<CallMuteSet>((event, emit) => _setMuted(emit, muted: event.muted));
    on<CallSpeakerToggled>(_onSpeakerToggled);
    on<_CallAudioChanged>(_onAudioChanged);
    on<_CallRingTimedOut>(_onRingTimedOut);
    on<_CallStatusPolled>(_onStatusPolled);

    _audioEvents = _audio.events.listen((event) {
      if (!isClosed) add(_CallAudioChanged(event));
    });
  }

  /// How long an outgoing call rings before giving up. Matches the ringing
  /// time the receiver's phone is given.
  static const defaultRingTimeout = Duration(seconds: 45);

  /// How long an answered call waits for the caller's audio to arrive.
  static const defaultConnectTimeout = Duration(seconds: 20);

  /// How often a ringing outgoing call asks whether it was declined.
  static const defaultStatusPollInterval = Duration(seconds: 3);

  final CallRepository _calls;
  final CallAudio _audio;
  final MicrophonePermission _microphone;
  final DateTime Function() _clock;
  final Duration ringTimeout;
  final Duration connectTimeout;
  final Duration statusPollInterval;

  late final StreamSubscription<CallAudioEvent> _audioEvents;
  Timer? _ringTimer;
  Timer? _statusTimer;
  bool _polling = false;

  /// Set once the API has the call, so hanging up can end it there too.
  int? _callId;

  /// Answered calls only: whether the API has it as accepted, which decides
  /// whether hanging up declines it or ends it.
  bool _accepted = false;

  Future<void> _onStarted(CallStarted event, Emitter<CallState> emit) async {
    if (state.phase != CallPhase.idle) return;
    emit(state.copyWith(phase: CallPhase.dialing));

    if (!await _microphone()) {
      return _finish(emit, CallEndReason.microphoneDenied);
    }
    if (_abandoned(emit)) return;

    final created = await _calls.create(event.receiverId);
    final Call call;
    switch (created) {
      case Err(:final failure):
        return _finish(emit, CallEndReason.failed, failure: failure);
      case Ok(:final value):
        call = value;
    }
    if (_abandoned(emit)) {
      // Hung up while the API was still creating it: nothing else knows the
      // id yet, so the other phone would ring on.
      unawaited(_calls.end(call.id));
      return;
    }
    _callId = call.id;

    if (!await _joinChannel(emit, call.id)) return;

    _waitForPeer(emit, timeout: ringTimeout);
    if (state.phase != CallPhase.ringing) return;
    // Nothing pushes a decline to the caller; it has to ask.
    _statusTimer = Timer.periodic(statusPollInterval, (_) {
      if (!isClosed) add(const _CallStatusPolled());
    });
  }

  Future<void> _onAnswered(CallAnswered event, Emitter<CallState> emit) async {
    if (state.phase != CallPhase.idle) return;
    final id = event.callId;
    // Known from the push already: hanging up from here on declines it.
    _callId = id;
    emit(state.copyWith(phase: CallPhase.dialing, incoming: true));

    if (!await _microphone()) {
      return _finish(emit, CallEndReason.microphoneDenied);
    }
    if (_abandoned(emit)) return;

    final accepted = await _calls.accept(id);
    if (accepted.isOk) _accepted = true;
    if (_abandoned(emit)) {
      // The hang-up declined it, but the accept landed first: end it instead,
      // or the caller sits in the channel waiting.
      if (accepted.isOk) unawaited(_calls.end(id));
      return;
    }
    if (accepted case Err(:final failure)) {
      return _finish(emit, CallEndReason.failed, failure: failure);
    }

    if (!await _joinChannel(emit, id)) return;
    _waitForPeer(emit, timeout: connectTimeout);
  }

  /// Token, then channel. `false` when the call ended on the way, in which
  /// case it has been cleaned up already.
  Future<bool> _joinChannel(Emitter<CallState> emit, int callId) async {
    final credentials = await _calls.credentials(callId);
    if (_abandoned(emit)) return false;
    if (credentials case Err(:final failure)) {
      await _finish(emit, CallEndReason.failed, failure: failure);
      return false;
    }

    final joined = await _audio.join(credentials.valueOrNull!);
    if (_abandoned(emit)) {
      // The hang-up ran while the SDK was joining, when there was no channel
      // to leave yet.
      await _audio.leave();
      return false;
    }
    if (joined case Err(:final failure)) {
      await _finish(emit, CallEndReason.failed, failure: failure);
      return false;
    }
    return true;
  }

  void _waitForPeer(Emitter<CallState> emit, {required Duration timeout}) {
    // The other person can be in the channel already, if their join raced
    // ours; that event has moved the call on, and must not be undone here.
    if (state.phase != CallPhase.dialing) return;
    emit(state.copyWith(phase: CallPhase.ringing));
    _ringTimer = Timer(timeout, () {
      if (!isClosed) add(const _CallRingTimedOut());
    });
  }

  Future<void> _onHungUp(CallHungUp event, Emitter<CallState> emit) =>
      _finish(emit, CallEndReason.hungUp);

  Future<void> _onRingTimedOut(
    _CallRingTimedOut event,
    Emitter<CallState> emit,
  ) async {
    if (state.phase != CallPhase.ringing) return;
    // An answered call whose caller never showed up did not fail to be
    // answered — it failed to connect.
    await _finish(
      emit,
      state.incoming ? CallEndReason.failed : CallEndReason.noAnswer,
    );
  }

  Future<void> _onStatusPolled(
    _CallStatusPolled event,
    Emitter<CallState> emit,
  ) async {
    final id = _callId;
    if (state.phase != CallPhase.ringing || id == null || _polling) return;

    _polling = true;
    final status = await _calls.status(id);
    _polling = false;
    if (state.phase != CallPhase.ringing) return;

    switch (status.valueOrNull) {
      case CallStatus.rejected:
        await _finish(emit, CallEndReason.rejected);
      case CallStatus.missed || CallStatus.ended:
        await _finish(emit, CallEndReason.noAnswer);
      case _:
        // Still ringing, or accepted with the audio about to arrive — and a
        // failed poll is simply tried again on the next tick.
        break;
    }
  }

  Future<void> _onAudioChanged(
    _CallAudioChanged event,
    Emitter<CallState> emit,
  ) async {
    if (state.phase == CallPhase.idle || state.isOver) return;

    switch (event.event) {
      case CallAudioJoined():
        break;
      case CallAudioPeerJoined():
        if (state.phase == CallPhase.active) return;
        _ringTimer?.cancel();
        _statusTimer?.cancel();
        emit(state.copyWith(phase: CallPhase.active, connectedAt: _clock()));
      case CallAudioPeerLeft():
        await _finish(emit, CallEndReason.peerLeft);
      case CallAudioFailed(:final reason):
        await _finish(
          emit,
          CallEndReason.failed,
          failure: UnknownFailure(debugMessage: 'Agora: $reason'),
        );
    }
  }

  Future<void> _setMuted(Emitter<CallState> emit, {required bool muted}) async {
    if (!state.hasAudio || state.muted == muted) return;
    emit(state.copyWith(muted: muted));
    await _audio.setMuted(muted);
  }

  Future<void> _onSpeakerToggled(
    CallSpeakerToggled event,
    Emitter<CallState> emit,
  ) async {
    if (!state.hasAudio) return;
    final speakerphone = !state.speakerphone;
    emit(state.copyWith(speakerphone: speakerphone));
    await _audio.setSpeakerphone(speakerphone);
  }

  /// Ends the call everywhere: on screen, in the channel and on the API.
  Future<void> _finish(
    Emitter<CallState> emit,
    CallEndReason reason, {
    Failure? failure,
  }) async {
    if (state.isOver) return;
    emit(
      state.copyWith(
        phase: CallPhase.ended,
        endReason: reason,
        failure: () => failure,
      ),
    );
    await _hangUpEverywhere();
  }

  Future<void> _hangUpEverywhere() async {
    _ringTimer?.cancel();
    _statusTimer?.cancel();
    await _audio.leave();
    final id = _callId;
    if (id == null) return;
    _callId = null;
    // The outcome is ignored on purpose: the call is over for this user
    // whatever the server says, and a row left behind is not theirs to fix.
    if (state.incoming && !_accepted) {
      await _calls.reject(id);
    } else {
      await _calls.end(id);
    }
  }

  /// The call was hung up, or the bloc closed, while a handler was awaiting.
  bool _abandoned(Emitter<CallState> emit) => emit.isDone || state.isOver;

  @override
  Future<void> close() async {
    _ringTimer?.cancel();
    _statusTimer?.cancel();
    await _audioEvents.cancel();
    // The screen went away mid-call — a back gesture, the route replaced.
    if (!state.isOver) await _hangUpEverywhere();
    return super.close();
  }
}
