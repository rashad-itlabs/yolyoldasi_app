import '../../../../core/error/result.dart';
import '../entities/call.dart';

/// The audio half of a call: one channel at a time, microphone in, the other
/// person's voice out.
///
/// An interface so the call bloc can be driven in tests without the Agora SDK,
/// which needs a real device.
abstract interface class CallAudio {
  /// What happens in the channel after [join]: the other person arriving and
  /// leaving, and the connection giving up.
  Stream<CallAudioEvent> get events;

  /// Joins the channel the credentials are for, publishing the microphone.
  ///
  /// Completing only means the request was accepted by the SDK; being in the
  /// channel is reported later as [CallAudioJoined].
  FutureResult<void> join(CallCredentials credentials);

  /// Leaves the current channel, if any. Safe to call more than once.
  Future<void> leave();

  Future<void> setMuted(bool muted);

  Future<void> setSpeakerphone(bool enabled);
}

sealed class CallAudioEvent {
  const CallAudioEvent();
}

/// This device is in the channel.
final class CallAudioJoined extends CallAudioEvent {
  const CallAudioJoined();
}

/// The other person joined the channel — the call is now actually connected.
final class CallAudioPeerJoined extends CallAudioEvent {
  const CallAudioPeerJoined(this.uid);

  final int uid;
}

/// The other person left the channel or dropped off it.
final class CallAudioPeerLeft extends CallAudioEvent {
  const CallAudioPeerLeft(this.uid);

  final int uid;
}

/// The connection is gone for good: a rejected or expired token, a wrong app
/// id, or a network that never came back.
final class CallAudioFailed extends CallAudioEvent {
  const CallAudioFailed(this.reason);

  /// Developer-facing; never shown to users.
  final String reason;
}
