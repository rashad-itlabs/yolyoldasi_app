package yolyoldasi.az

import com.hiennv.flutter_callkit_incoming.CallkitIncomingBroadcastReceiver
import com.hiennv.flutter_callkit_incoming.Data
import com.onesignal.notifications.INotificationReceivedEvent
import com.onesignal.notifications.INotificationServiceExtension
import org.json.JSONObject

/**
 * Turns the API's call pushes into a ringing phone — Android's counterpart to
 * the PushKit handler in the iOS AppDelegate.
 *
 * OneSignal runs this for every push it receives, including when the app is
 * not running, before anything is shown. A call push is taken out of the
 * normal notification path and handed to flutter_callkit_incoming, which rings
 * with a full-screen incoming-call UI. Accepting it opens the app, where
 * `IncomingCalls` picks the call up (from the event, or from `activeCalls()`
 * on a cold start).
 *
 * Registered in AndroidManifest.xml under `com.onesignal.NotificationServiceExtension`.
 * OneSignal's own consumer ProGuard rules keep implementations of the interface.
 */
class IncomingCallNotificationExtension : INotificationServiceExtension {
    override fun onNotificationReceived(event: INotificationReceivedEvent) {
        val payload = event.notification.additionalData ?: return
        val context = event.context

        when (payload.optString("type")) {
            "incoming_call" -> {
                event.preventDefault()
                val data = Data(incomingCall(payload))
                context.sendBroadcast(
                    CallkitIncomingBroadcastReceiver.getIntentIncoming(context, data.toBundle())
                )
            }
            // The caller hung up before anyone answered. Unlike on iOS this can
            // be pushed, and it is the only way to silence a phone whose app is
            // not running to ask.
            "call_cancelled" -> {
                event.preventDefault()
                val data = Data(hashMapOf<String, Any?>("id" to payload.optString("uuid")))
                context.sendBroadcast(
                    CallkitIncomingBroadcastReceiver.getIntentEnded(context, data.toBundle())
                )
            }
        }
    }

    /** The plugin's call data, in the shape its Dart API would have sent. */
    private fun incomingCall(payload: JSONObject): Map<String, Any?> {
        val name = payload.optString("caller_name").ifEmpty { "Yol Yoldaşı" }
        val photo = payload.optString("caller_photo")

        return hashMapOf(
            "id" to payload.optString("uuid"),
            "nameCaller" to name,
            "appName" to "Yol Yoldaşı",
            "handle" to name,
            "avatar" to photo,
            "type" to 0,
            // Matches how long the caller's app keeps ringing.
            "duration" to 45000L,
            // Read back by CallKitService in Dart, exactly as on iOS.
            "extra" to hashMapOf<String, Any?>(
                "call_id" to payload.optInt("call_id"),
                "caller_id" to payload.optInt("caller_id"),
                "caller_name" to name,
                "caller_photo" to photo,
            ),
            // The plugin's own missed-call notification is English-only.
            "missedCallNotification" to hashMapOf<String, Any?>("showNotification" to false),
            "callingNotification" to hashMapOf<String, Any?>(
                "showNotification" to true,
                "subtitle" to payload.optString("text_calling"),
                "callbackText" to payload.optString("text_hang_up"),
                "isShowCallback" to true,
            ),
            "android" to hashMapOf<String, Any?>(
                "isShowFullLockedScreen" to true,
                "isCustomNotification" to false,
                // The words are the server's, in the receiver's language: this
                // screen is drawn natively, out of reach of the app's strings.
                "textAccept" to payload.optString("text_accept"),
                "textDecline" to payload.optString("text_decline"),
            ),
        )
    }
}
