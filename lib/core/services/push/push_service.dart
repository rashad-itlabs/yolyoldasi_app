import 'dart:async';

import 'push_message.dart';

/// The push transport, behind an interface so nothing above it knows which one
/// is wired — or whether one is wired at all.
///
/// The seam exists because the transport is the only part that needs vendor
/// credentials. Everything else — channels, permission, routing, token
/// registration, foreground rendering — is written against this interface and
/// works unchanged whether the messages arrive over FCM, over APNs directly, or
/// not at all.
///
/// Delivery itself never runs through here. When the phone is locked and the
/// app is dead, the notification is drawn by the OS from the transport's own
/// process; this object only sees what happens once the app is alive again.
abstract interface class PushService {
  /// Prepares the transport and asks for notification permission.
  ///
  /// Returns whether push can actually be delivered — false when permission was
  /// refused, or when no transport is configured. Safe to call more than once.
  Future<bool> start();

  /// The registration token this device is currently known by.
  ///
  /// Null before [start], when permission was refused, or when there is no
  /// transport. This is the value `POST /me/device-tokens` takes, and the value
  /// `DELETE /me/device-tokens` must be given before sign-out — see
  /// [AuthRepository.logout].
  String? get currentToken;

  /// Tokens as they are issued and rotated.
  ///
  /// Rotation is not an edge case: a restore, a reinstall or a data clear all
  /// produce a new token, and the server keeps sending to the old one until it
  /// is told. Every value here must be re-registered.
  Stream<String> get tokenChanges;

  /// Messages that arrived while the app was in the foreground.
  ///
  /// Only the foreground. FCM deliberately draws nothing on Android while the
  /// app is on screen, and iOS needs to be told to; either way this is the one
  /// state where the app is responsible for the notification itself.
  Stream<PushMessage> get foregroundMessages;

  /// Notification taps, including the one that cold-started the app.
  ///
  /// A cold-start tap is replayed here once a listener attaches, so a tap that
  /// launched the process is not lost to the gap before the UI is ready.
  Stream<PushMessage> get taps;

  /// Drops the local registration. Called after the API has been told to forget
  /// the token, so a signed-out device stops receiving the previous account's
  /// notifications even if it is never signed in again.
  Future<void> clear();

  Future<void> dispose();
}

/// The transport that does nothing, used while none is configured.
///
/// It is not a test double: it is what ships until `google-services.json` and
/// an APNs key exist. Everything above it — the channels, the permission
/// prompt, the deep-link routing, the foreground renderer — is live and
/// exercised; only delivery is absent. [currentToken] stays null, so the
/// registration call is skipped rather than posting a placeholder the server
/// would later try to send to.
class InactivePushService implements PushService {
  const InactivePushService();

  @override
  Future<bool> start() async => false;

  @override
  String? get currentToken => null;

  @override
  Stream<String> get tokenChanges => const Stream<String>.empty();

  @override
  Stream<PushMessage> get foregroundMessages =>
      const Stream<PushMessage>.empty();

  @override
  Stream<PushMessage> get taps => const Stream<PushMessage>.empty();

  @override
  Future<void> clear() async {}

  @override
  Future<void> dispose() async {}
}
