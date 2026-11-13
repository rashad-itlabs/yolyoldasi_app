import 'package:equatable/equatable.dart';

/// A call row on the API — what `POST /calls` creates.
///
/// The call itself is only bookkeeping: who rang whom, and which Agora channel
/// the two of them meet in. The audio never touches the API.
class Call extends Equatable {
  const Call({
    required this.id,
    required this.callerId,
    required this.receiverId,
    required this.channelName,
  });

  final int id;
  final int callerId;
  final int receiverId;
  final String channelName;

  @override
  List<Object?> get props => [id, callerId, receiverId, channelName];
}

/// What it takes to join a call's Agora channel — `GET /calls/{id}/token`.
///
/// The token is minted for this user and this channel only, and it expires
/// (an hour by default, `services.agora.expiration` on the API).
class CallCredentials extends Equatable {
  const CallCredentials({
    required this.appId,
    required this.channelName,
    required this.uid,
    required this.token,
  });

  final String appId;
  final String channelName;

  /// The user's own id. The token is bound to it, so joining under any other
  /// uid is refused by Agora.
  final int uid;
  final String token;

  @override
  List<Object?> get props => [appId, channelName, uid, token];
}

/// Where a call row is on the API — `GET /calls/{id}`.
enum CallStatus {
  ringing,
  accepted,

  /// The receiver declined it.
  rejected,
  ended,

  /// Never picked up: the caller hung up first, or it rang out.
  missed,

  /// A value this build does not know yet.
  unknown;

  static CallStatus fromApi(String value) => switch (value) {
    'ringing' => ringing,
    'accepted' => accepted,
    'rejected' => rejected,
    'ended' => ended,
    'missed' => missed,
    _ => unknown,
  };

  bool get isOver => this == rejected || this == ended || this == missed;
}

/// A call ringing on this phone, as the VoIP push and CallKit describe it.
class IncomingCall extends Equatable {
  const IncomingCall({
    required this.uuid,
    required this.callId,
    required this.caller,
  });

  /// CallKit's identity for the call; the API's channel name carries it.
  final String uuid;
  final int callId;
  final CallPeer caller;

  @override
  List<Object?> get props => [uuid, callId, caller];
}

/// The person on the other end, as far as the call screen needs to show them.
///
/// Passed along from the profile the call was started from, so the screen has
/// a name and a face before anything has loaded.
class CallPeer extends Equatable {
  const CallPeer({required this.userId, this.name = '', this.photoUrl});

  final int userId;
  final String name;
  final String? photoUrl;

  @override
  List<Object?> get props => [userId, name, photoUrl];
}
