part of 'call_bloc.dart';

sealed class CallEvent extends Equatable {
  const CallEvent();

  @override
  List<Object?> get props => [];
}

/// The call screen opened: ring [receiverId].
final class CallStarted extends CallEvent {
  const CallStarted(this.receiverId);

  final int receiverId;

  @override
  List<Object?> get props => [receiverId];
}

/// The user picked up call [callId] on the phone's call screen.
final class CallAnswered extends CallEvent {
  const CallAnswered(this.callId);

  final int callId;

  @override
  List<Object?> get props => [callId];
}

final class CallHungUp extends CallEvent {
  const CallHungUp();
}

final class CallMuteToggled extends CallEvent {
  const CallMuteToggled();
}

/// Mute set from outside the app's own screen — the system call screen.
final class CallMuteSet extends CallEvent {
  const CallMuteSet({required this.muted});

  final bool muted;

  @override
  List<Object?> get props => [muted];
}

final class CallSpeakerToggled extends CallEvent {
  const CallSpeakerToggled();
}

final class _CallAudioChanged extends CallEvent {
  const _CallAudioChanged(this.event);

  final CallAudioEvent event;

  @override
  List<Object?> get props => [event];
}

final class _CallRingTimedOut extends CallEvent {
  const _CallRingTimedOut();
}

final class _CallStatusPolled extends CallEvent {
  const _CallStatusPolled();
}
