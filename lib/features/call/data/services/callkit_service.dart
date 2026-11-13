import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import '../../domain/entities/call.dart';
import '../../domain/services/system_call_ui.dart';

/// [SystemCallUi] over `flutter_callkit_incoming` — CallKit on iPhone, the
/// plugin's full-screen call UI on Android.
///
/// The ringing itself is started natively, before Dart could be asked: by the
/// PushKit handler in `AppDelegate.swift` (iOS wants the VoIP push handed to
/// CallKit before the handler returns), and by the OneSignal extension in
/// `IncomingCallNotificationExtension.kt` (it runs with the app not running).
/// Both put the push's fields in the call's `extra`, and this reads them back.
class CallKitService implements SystemCallUi {
  CallKitService();

  /// Built once and shared by every listener — never one stream each.
  ///
  /// `FlutterCallkitIncoming.onEvent` makes a new `receiveBroadcastStream()`
  /// on every read, and an `EventChannel` keeps a single message handler per
  /// channel: each new stream replaces the last one's, and the replaced stream
  /// goes silent without an error. That is how an answered call once never
  /// reached the app — `AppStartup` started listening for VoIP tokens after
  /// `IncomingCalls` had started listening for calls, and took the channel.
  @override
  late final Stream<SystemCallEvent> events = FlutterCallkitIncoming.onEvent
      // The plugin throws on a body it cannot read; one bad event must not
      // close the stream every later call depends on.
      .handleError((Object error) => debugPrint('CallKit: dropped $error'))
      .asyncMap(_translate)
      .where((event) => event != null)
      .cast<SystemCallEvent>();

  @override
  Future<String?> voipToken() async {
    final token = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
    return (token == null || token.isEmpty) ? null : token;
  }

  @override
  Future<List<({IncomingCall call, bool accepted})>> activeCalls() async {
    final calls = await FlutterCallkitIncoming.activeCalls();
    return [
      for (final params in calls)
        if (_incoming(params) case final call?)
          (call: call, accepted: params.isAccepted),
    ];
  }

  @override
  Future<void> reportConnected(String uuid) =>
      FlutterCallkitIncoming.setCallConnected(uuid);

  @override
  Future<void> reportEnded(String uuid) => FlutterCallkitIncoming.endCall(uuid);

  @override
  Future<void> setMuted(String uuid, bool muted) =>
      FlutterCallkitIncoming.muteCall(uuid, isMuted: muted);

  Future<SystemCallEvent?> _translate(CallEvent? event) async {
    switch (event) {
      case CallEventActionDidUpdateDevicePushTokenVoip():
        // The event says only that the token changed, not what it now is.
        final token = await voipToken();
        return token == null ? null : SystemVoipTokenChanged(token);
      case CallEventActionCallIncoming(:final callKitParams):
        final call = _incoming(callKitParams);
        return call == null ? null : SystemCallRinging(call);
      case CallEventActionCallAccept(:final callKitParams):
        final call = _incoming(callKitParams);
        return call == null ? null : SystemCallAccepted(call);
      case CallEventActionCallDecline(:final callKitParams):
        final call = _incoming(callKitParams);
        return call == null ? null : SystemCallDeclined(call);
      case CallEventActionCallEnded(:final callKitParams):
        return SystemCallEnded(callKitParams.id);
      case CallEventActionCallTimeout(:final id):
        return SystemCallTimedOut(id);
      case CallEventActionCallToggleMute(:final id, :final isMuted):
        return SystemCallMuteChanged(id, muted: isMuted);
      default:
        return null;
    }
  }

  /// The call the VoIP push described, or null for one this app did not
  /// start (no call id in `extra`).
  static IncomingCall? _incoming(CallKitParams params) {
    final extra = params.extra ?? const <String, dynamic>{};
    final callId = _int(extra['call_id']);
    if (callId == null || callId <= 0) return null;

    final photo = extra['caller_photo'];
    return IncomingCall(
      uuid: params.id,
      callId: callId,
      caller: CallPeer(
        userId: _int(extra['caller_id']) ?? 0,
        name: (extra['caller_name'] as String?) ?? params.nameCaller ?? '',
        photoUrl: photo is String && photo.isNotEmpty ? photo : null,
      ),
    );
  }

  static int? _int(Object? value) => switch (value) {
    final int v => v,
    final num v => v.toInt(),
    final String v => int.tryParse(v),
    _ => null,
  };
}

/// [SystemCallUi] for platforms with no call UI wired — desktop, and
/// every test. Nothing rings, nothing is reported.
class InactiveSystemCallUi implements SystemCallUi {
  const InactiveSystemCallUi();

  @override
  Stream<SystemCallEvent> get events => const Stream.empty();

  @override
  Future<String?> voipToken() async => null;

  @override
  Future<List<({IncomingCall call, bool accepted})>> activeCalls() async =>
      const [];

  @override
  Future<void> reportConnected(String uuid) async {}

  @override
  Future<void> reportEnded(String uuid) async {}

  @override
  Future<void> setMuted(String uuid, bool muted) async {}
}
