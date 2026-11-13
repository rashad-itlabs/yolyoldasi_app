part of 'call_bloc.dart';

enum CallPhase {
  idle,

  /// Asking for the microphone, creating or accepting the call, fetching the
  /// token and joining the channel.
  dialing,

  /// In the channel, waiting for the other person: for the caller, waiting
  /// for them to pick up; for the receiver, for the caller's audio to arrive.
  ringing,

  /// Both people are in the channel.
  active,

  ended,
}

enum CallEndReason {
  hungUp,
  noAnswer,

  /// The receiver declined.
  rejected,

  /// The other person hung up or dropped off.
  peerLeft,
  microphoneDenied,
  failed,
}

class CallState extends Equatable {
  const CallState({
    this.phase = CallPhase.idle,
    this.incoming = false,
    this.connectedAt,
    this.muted = false,
    this.speakerphone = false,
    this.endReason,
    this.failure,
  });

  final CallPhase phase;

  /// Answered on this phone, rather than dialled from it.
  final bool incoming;

  /// When the other person joined; the call screen counts from here.
  final DateTime? connectedAt;

  final bool muted;
  final bool speakerphone;

  /// Set once [phase] is [CallPhase.ended].
  final CallEndReason? endReason;

  /// What went wrong, for [CallEndReason.failed].
  final Failure? failure;

  bool get isOver => phase == CallPhase.ended;

  /// Mute and speaker only mean something once the microphone is live.
  bool get hasAudio => phase == CallPhase.ringing || phase == CallPhase.active;

  CallState copyWith({
    CallPhase? phase,
    bool? incoming,
    DateTime? connectedAt,
    bool? muted,
    bool? speakerphone,
    CallEndReason? endReason,
    Failure? Function()? failure,
  }) {
    return CallState(
      phase: phase ?? this.phase,
      incoming: incoming ?? this.incoming,
      connectedAt: connectedAt ?? this.connectedAt,
      muted: muted ?? this.muted,
      speakerphone: speakerphone ?? this.speakerphone,
      endReason: endReason ?? this.endReason,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [
    phase,
    incoming,
    connectedAt,
    muted,
    speakerphone,
    endReason,
    failure,
  ];
}
