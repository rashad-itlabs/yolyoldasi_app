import '../entities/call.dart';

/// The phone's own call screen — CallKit on iPhone.
///
/// An incoming call reaches the app as a VoIP push, and iOS insists the app
/// hand it to CallKit at once: the ringing, the lock-screen answer slider and
/// the hang-up button all belong to the system. This is the app's side of that
/// conversation, behind an interface so the coordinator can be tested without
/// a device.
abstract interface class SystemCallUi {
  /// What the user did on the system screen, and new VoIP tokens.
  Stream<SystemCallEvent> get events;

  /// This phone's PushKit token, or null where there is none (Android, the
  /// simulator, before iOS has issued one).
  Future<String?> voipToken();

  /// Calls the system is showing right now. A push that cold-starts the app
  /// can be answered before Dart is listening, so the coordinator looks here
  /// once at launch rather than trusting it saw every event.
  Future<List<({IncomingCall call, bool accepted})>> activeCalls();

  /// The other person is in the channel; the system screen starts its clock.
  Future<void> reportConnected(String uuid);

  /// Takes the call off the system screen, ringing or not.
  Future<void> reportEnded(String uuid);

  Future<void> setMuted(String uuid, bool muted);
}

sealed class SystemCallEvent {
  const SystemCallEvent();
}

/// The system started ringing for [call].
final class SystemCallRinging extends SystemCallEvent {
  const SystemCallRinging(this.call);

  final IncomingCall call;
}

final class SystemCallAccepted extends SystemCallEvent {
  const SystemCallAccepted(this.call);

  final IncomingCall call;
}

/// Declined while ringing — by the user, or because the app ended a ringing
/// call itself (CallKit reports both the same way).
final class SystemCallDeclined extends SystemCallEvent {
  const SystemCallDeclined(this.call);

  final IncomingCall call;
}

/// Hung up from the system screen, or taken off it by [SystemCallUi.reportEnded].
final class SystemCallEnded extends SystemCallEvent {
  const SystemCallEnded(this.uuid);

  final String uuid;
}

/// Rang out with nobody answering.
final class SystemCallTimedOut extends SystemCallEvent {
  const SystemCallTimedOut(this.uuid);

  final String uuid;
}

/// The mute button on the system screen.
final class SystemCallMuteChanged extends SystemCallEvent {
  const SystemCallMuteChanged(this.uuid, {required this.muted});

  final String uuid;
  final bool muted;
}

/// iOS issued a new PushKit token; the server needs it to ring this phone.
final class SystemVoipTokenChanged extends SystemCallEvent {
  const SystemVoipTokenChanged(this.token);

  final String token;
}
