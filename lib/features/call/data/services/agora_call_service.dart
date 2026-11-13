import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/error/result.dart';
import '../../domain/entities/call.dart';
import '../../domain/services/call_audio.dart';

/// [CallAudio] over the Agora RTC SDK.
///
/// One engine for the life of the app, created on the first call rather than
/// at boot: it loads a native library and starts audio threads, which nobody
/// who never makes a call should pay for.
///
/// The app id comes from `GET /calls/{id}/token`, not from a build constant,
/// so the Agora project can be switched on the server without a release.
class AgoraCallService implements CallAudio {
  RtcEngine? _engine;
  String? _engineAppId;
  bool _inChannel = false;

  final _events = StreamController<CallAudioEvent>.broadcast();

  /// Reasons after which Agora will not reconnect on its own.
  static const _fatalReasons = {
    ConnectionChangedReasonType.connectionChangedBannedByServer,
    ConnectionChangedReasonType.connectionChangedInvalidAppId,
    ConnectionChangedReasonType.connectionChangedInvalidChannelName,
    ConnectionChangedReasonType.connectionChangedInvalidToken,
    ConnectionChangedReasonType.connectionChangedTokenExpired,
    ConnectionChangedReasonType.connectionChangedRejectedByServer,
  };

  @override
  Stream<CallAudioEvent> get events => _events.stream;

  @override
  FutureResult<void> join(CallCredentials credentials) => guard(() async {
    final engine = await _engineFor(credentials.appId);

    // Agora refuses a join while this device is still in a channel (-17), so
    // a call that somehow never left must not block the next one.
    if (_inChannel) await leave();

    await engine.joinChannel(
      token: credentials.token,
      channelId: credentials.channelName,
      uid: credentials.uid,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        publishCameraTrack: false,
        autoSubscribeAudio: true,
        autoSubscribeVideo: false,
      ),
    );
    _inChannel = true;

    // Mute is engine state, not channel state: a call that ended muted would
    // otherwise start the next one silent.
    await engine.muteLocalAudioStream(false);
  });

  @override
  Future<void> leave() async {
    final engine = _engine;
    if (engine == null || !_inChannel) return;
    _inChannel = false;
    try {
      await engine.leaveChannel();
    } on Object catch (error) {
      debugPrint('Agora: leaveChannel failed: $error');
    }
  }

  @override
  Future<void> setMuted(bool muted) async {
    await _engine?.muteLocalAudioStream(muted);
  }

  /// Only lasts for the current channel: the next call starts on the earpiece
  /// again, which is the default set in [_engineFor].
  @override
  Future<void> setSpeakerphone(bool enabled) async {
    await _engine?.setEnableSpeakerphone(enabled);
  }

  /// Not called in the app — the engine lives as long as the process — but
  /// keeps the service disposable for tests and a future sign-out hook.
  Future<void> dispose() async {
    await leave();
    await _release();
    await _events.close();
  }

  // --------------------------------------------------------------- plumbing

  Future<RtcEngine> _engineFor(String appId) async {
    final current = _engine;
    if (current != null && _engineAppId == appId) return current;

    // The server switched Agora projects since the last call.
    if (current != null) await _release();

    final engine = createAgoraRtcEngine();
    try {
      await engine.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
      engine.registerEventHandler(_handler);
      await engine.enableAudio();
      // A phone call is held to the ear; the speaker is a button away.
      await engine.setDefaultAudioRouteToSpeakerphone(false);
    } on Object {
      await engine.release();
      rethrow;
    }

    _engine = engine;
    _engineAppId = appId;
    return engine;
  }

  Future<void> _release() async {
    final engine = _engine;
    if (engine == null) return;
    _engine = null;
    _engineAppId = null;
    _inChannel = false;
    engine.unregisterEventHandler(_handler);
    await engine.release();
  }

  void _emit(CallAudioEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  late final RtcEngineEventHandler _handler = RtcEngineEventHandler(
    onJoinChannelSuccess: (_, _) => _emit(const CallAudioJoined()),
    onUserJoined: (_, remoteUid, _) => _emit(CallAudioPeerJoined(remoteUid)),
    onUserOffline: (_, remoteUid, _) => _emit(CallAudioPeerLeft(remoteUid)),
    onConnectionStateChanged: (_, state, reason) {
      if (state == ConnectionStateType.connectionStateFailed ||
          _fatalReasons.contains(reason)) {
        _emit(CallAudioFailed('${state.name} / ${reason.name}'));
      }
    },
    // Most of what arrives here is recoverable and followed by a connection
    // state change if it is not, so it is logged rather than acted on.
    onError: (err, msg) => debugPrint('Agora error: ${err.name} $msg'),
  );
}
