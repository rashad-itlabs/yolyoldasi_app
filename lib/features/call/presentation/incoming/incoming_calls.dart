import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/call.dart';
import '../../domain/repositories/call_repository.dart';
import '../../domain/services/system_call_ui.dart';
import '../bloc/call_bloc.dart';

/// An answered call and the bloc running it.
class ActiveIncomingCall {
  const ActiveIncomingCall({required this.call, required this.bloc});

  final IncomingCall call;
  final CallBloc bloc;
}

/// Answers, declines and runs the calls that ring on this phone.
///
/// Lives as long as the app and is started from `main`, not from a widget: a
/// VoIP push launches a killed app in the background, where no frame is drawn
/// and no `initState` runs — yet the call has to be accepted and its audio
/// started from right there, on the lock screen.
///
/// The system call screen is the call's real UI. The app's own screen, shown
/// over everything while [active] is set, is a second view of the same bloc.
class IncomingCalls extends ChangeNotifier {
  IncomingCalls({
    required CallRepository calls,
    required SystemCallUi system,
    required CallBloc Function() createBloc,
    this.statusPollInterval = const Duration(seconds: 3),
    this.lingerAfterEnd = const Duration(seconds: 2),
  }) : _calls = calls,
       _system = system,
       _createBloc = createBloc;

  final CallRepository _calls;
  final SystemCallUi _system;
  final CallBloc Function() _createBloc;

  /// How often a ringing call asks whether the caller has given up. Nothing
  /// can push that: Apple forbids a VoIP push that does not ring.
  final Duration statusPollInterval;

  /// How long the app's screen shows "call ended" before going away.
  final Duration lingerAfterEnd;

  ActiveIncomingCall? _active;
  ActiveIncomingCall? get active => _active;

  StreamSubscription<SystemCallEvent>? _events;
  StreamSubscription<CallState>? _activeStates;
  Timer? _linger;

  /// Ringing calls being polled, by CallKit uuid.
  final _watched = <String, Timer>{};

  /// Calls already answered or declined here, so a cold start that finds a
  /// call both in [SystemCallUi.activeCalls] and in a late event acts once.
  final _handled = <String>{};

  /// Calls this app took off the system screen itself. CallKit reports those
  /// back as declined or ended, which must not be read as the user's answer.
  final _dismissedByApp = <String>{};

  Future<void> start() async {
    if (_events != null) return;
    _events = _system.events.listen(_onEvent);

    // A push that cold-started the app may have been answered before anything
    // was listening.
    for (final (:call, :accepted) in await _system.activeCalls()) {
      if (accepted) {
        _answer(call);
      } else {
        _watch(call);
      }
    }
  }

  /// Puts the app's screen away once the call is over.
  void dismiss() {
    final active = _active;
    if (active == null) return;
    _linger?.cancel();
    _activeStates?.cancel();
    _active = null;
    if (!active.bloc.state.isOver) _endOnSystem(active.call.uuid);
    // Closing hangs up if the call is somehow still live.
    unawaited(active.bloc.close());
    notifyListeners();
  }

  void _onEvent(SystemCallEvent event) {
    switch (event) {
      case SystemCallRinging(:final call):
        _watch(call);
      case SystemCallAccepted(:final call):
        _answer(call);
      case SystemCallDeclined(:final call):
        _decline(call);
      case SystemCallEnded(:final uuid):
        _onSystemEnded(uuid);
      case SystemCallTimedOut(:final uuid):
        // The caller's own timeout marks it missed on the API.
        _unwatch(uuid);
      case SystemCallMuteChanged(:final uuid, :final muted):
        final active = _active;
        if (active != null && active.call.uuid == uuid) {
          active.bloc.add(CallMuteSet(muted: muted));
        }
      case SystemVoipTokenChanged():
        // Registered by AppStartup, which knows whether anyone is signed in.
        break;
    }
  }

  void _answer(IncomingCall call) {
    _unwatch(call.uuid);
    if (!_handled.add(call.uuid)) return;

    if (_active != null) {
      // One call at a time. CallKit is set to a single call, so this is only
      // a second answer racing the first.
      _endOnSystem(call.uuid);
      unawaited(_calls.reject(call.callId));
      return;
    }

    _linger?.cancel();
    final bloc = _createBloc()..add(CallAnswered(call.callId));
    _active = ActiveIncomingCall(call: call, bloc: bloc);

    var reportedConnected = false;
    var muted = false;
    _activeStates = bloc.stream.listen((state) {
      if (state.phase == CallPhase.active && !reportedConnected) {
        reportedConnected = true;
        unawaited(_system.reportConnected(call.uuid));
      }
      // Muted on the app's screen: the system screen shows the same.
      if (state.muted != muted) {
        muted = state.muted;
        unawaited(_system.setMuted(call.uuid, state.muted));
      }
      if (state.isOver) _onActiveEnded(call, state);
    });
    notifyListeners();
  }

  void _onActiveEnded(IncomingCall call, CallState state) {
    _activeStates?.cancel();
    _endOnSystem(call.uuid);

    // A failure needs reading and a refused microphone offers the settings;
    // both stay until the user closes them.
    if (state.endReason
        case CallEndReason.failed || CallEndReason.microphoneDenied) {
      return;
    }
    _linger = Timer(lingerAfterEnd, dismiss);
  }

  void _decline(IncomingCall call) {
    _unwatch(call.uuid);
    if (_dismissedByApp.contains(call.uuid)) return;
    if (!_handled.add(call.uuid)) return;
    unawaited(_calls.reject(call.callId));
  }

  void _onSystemEnded(String uuid) {
    _unwatch(uuid);
    if (_dismissedByApp.contains(uuid)) return;
    final active = _active;
    if (active != null &&
        active.call.uuid == uuid &&
        !active.bloc.state.isOver) {
      active.bloc.add(const CallHungUp());
    }
  }

  void _watch(IncomingCall call) {
    if (_handled.contains(call.uuid) || _watched.containsKey(call.uuid)) {
      return;
    }
    _watched[call.uuid] = Timer.periodic(
      statusPollInterval,
      (_) => unawaited(_stopIfNoLongerRinging(call)),
    );
  }

  void _unwatch(String uuid) => _watched.remove(uuid)?.cancel();

  /// The caller hung up, or the account answered on another phone: stop
  /// ringing here.
  Future<void> _stopIfNoLongerRinging(IncomingCall call) async {
    final status = (await _calls.status(call.callId)).valueOrNull;
    if (status == null ||
        status == CallStatus.ringing ||
        status == CallStatus.unknown) {
      return;
    }
    if (!_watched.containsKey(call.uuid) || _handled.contains(call.uuid)) {
      return;
    }
    _unwatch(call.uuid);
    _endOnSystem(call.uuid);
  }

  void _endOnSystem(String uuid) {
    _dismissedByApp.add(uuid);
    unawaited(_system.reportEnded(uuid));
  }

  @override
  void dispose() {
    _events?.cancel();
    _activeStates?.cancel();
    _linger?.cancel();
    for (final timer in _watched.values) {
      timer.cancel();
    }
    _watched.clear();
    unawaited(_active?.bloc.close());
    super.dispose();
  }
}
