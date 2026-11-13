import Flutter
import PushKit
import UIKit
import flutter_callkit_incoming

@main
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate {
  /// Held for the life of the app: PushKit delivers only to a registry that
  /// still exists, and it has to be in place before launch finishes, or the
  /// VoIP push that launched a killed app is lost.
  private var voipRegistry: PKPushRegistry?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let registry = PKPushRegistry(queue: .main)
    registry.delegate = self
    registry.desiredPushTypes = [.voIP]
    voipRegistry = registry

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - PushKit

  /// Handed to Dart through the plugin, which registers it with
  /// `POST /me/voip-tokens` once someone is signed in.
  func pushRegistry(
    _ registry: PKPushRegistry,
    didUpdate pushCredentials: PKPushCredentials,
    for type: PKPushType
  ) {
    guard type == .voIP else { return }
    let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(token)
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    guard type == .voIP else { return }
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
  }

  /// An incoming call, sent by the API's `VoipPushService`.
  ///
  /// Every VoIP push must be reported to CallKit before this returns — iOS
  /// kills an app that does not, and stops delivering VoIP pushes to one that
  /// keeps not doing it. So even a push missing its fields still rings; the
  /// Dart side ignores a call it cannot match to a call id.
  func pushRegistry(
    _ registry: PKPushRegistry,
    didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType,
    completion: @escaping () -> Void
  ) {
    guard type == .voIP else {
      completion()
      return
    }

    let body = payload.dictionaryPayload
    let uuid = (body["uuid"] as? String).flatMap { UUID(uuidString: $0)?.uuidString }
      ?? UUID().uuidString
    let name = (body["caller_name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
      ?? "Yol Yoldaşı"
    let photo = body["caller_photo"] as? String ?? ""

    let data = flutter_callkit_incoming.Data(id: uuid, nameCaller: name, handle: name, type: 0)
    data.appName = "Yol Yoldaşı"
    data.avatar = photo
    // Matches how long the caller's app keeps ringing.
    data.duration = 45000
    data.extra = [
      "call_id": (body["call_id"] as? NSNumber)?.intValue ?? 0,
      "caller_id": (body["caller_id"] as? NSNumber)?.intValue ?? 0,
      "caller_name": name,
      "caller_photo": photo,
    ]
    // A voice call between two people, nothing more: no video, keypad,
    // hold or merge buttons, and no entry in the Phone app's recents that
    // would dial a number this call never had.
    data.supportsVideo = false
    data.supportsDTMF = false
    data.supportsHolding = false
    data.supportsGrouping = false
    data.supportsUngrouping = false
    data.maximumCallGroups = 1
    data.maximumCallsPerCallGroup = 1
    data.includesCallsInRecents = false
    // The plugin's missed-call notification is English-only; the app has
    // its own words for that.
    data.isShowMissedCallNotification = false
    // The plugin sets up the audio session when the call is answered, and
    // again 1.2 s later — by which time Agora is in the channel. Its defaults
    // are mode `.default`, 44.1 kHz and a 5 ms buffer. `.default` switches
    // off iOS's voice processing (echo cancellation, gain control), and a
    // 44.1 kHz rate on 48 kHz hardware has to be resampled mid-call. The
    // first call heard echo, the speech wavered, and it was this. These
    // values match what Agora sets for a voice call, so the second setup
    // changes nothing.
    data.audioSessionMode = "voiceChat"
    data.audioSessionPreferredSampleRate = 48000.0
    data.audioSessionPreferredIOBufferDuration = 0.01

    guard let plugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance else {
      completion()
      return
    }
    plugin.showCallkitIncoming(data, fromPushKit: true) {
      completion()
    }
  }
}
