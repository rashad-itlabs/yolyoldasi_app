import '../../../../core/error/result.dart';
import '../entities/call.dart';

/// The API side of a voice call: creating the call row, moving it through its
/// states, and fetching the Agora token to join its channel.
///
/// Status flow on the API: `ringing` → `accepted` | `rejected` | `missed`, and
/// `accepted` → `ended`.
abstract interface class CallRepository {
  /// `POST /calls`. Starts ringing [receiverId] — on an iPhone, as a real phone
  /// call through a VoIP push. 422 for calling yourself.
  FutureResult<Call> create(int receiverId);

  /// `GET /calls/{id}`. Polled while a call rings, because nothing pushes the
  /// other side's answer: the caller learns of a decline here, and a ringing
  /// phone learns that the caller gave up.
  FutureResult<CallStatus> status(int callId);

  /// `POST /calls/{id}/accept` — the receiver picks up.
  FutureResult<void> accept(int callId);

  /// `POST /calls/{id}/reject` — the receiver declines a ringing call. Safe
  /// to send for a call that is already over.
  FutureResult<void> reject(int callId);

  /// `POST /calls/{id}/end` — either side hangs up. The caller may also use it
  /// to cancel a call that is still ringing, which leaves it `missed`.
  FutureResult<void> end(int callId);

  /// `GET /calls/{id}/token`. The caller may fetch it while the call rings;
  /// the receiver only once they have accepted.
  FutureResult<CallCredentials> credentials(int callId);

  /// `POST /me/voip-tokens` — where this iPhone can be rung. Re-sending the
  /// same token is safe; the server drops it with the session on sign-out.
  FutureResult<void> registerVoipToken(String token);
}
