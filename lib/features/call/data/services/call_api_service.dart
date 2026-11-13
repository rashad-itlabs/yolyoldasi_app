import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/json_reader.dart';
import '../../domain/entities/call.dart';
import '../models/call_model.dart';

/// `/calls` — the bookkeeping side of an in-app voice call.
class CallApiService {
  const CallApiService(this._client);

  final ApiClient _client;

  FutureResult<Call> create(int receiverId) => _client.post(
    Api.calls,
    body: {'receiver_id': receiverId},
    parse: CallModel.fromJson,
  );

  FutureResult<CallStatus> status(int callId) => _client.getObject(
    Api.call(callId),
    parse: (json) => CallStatus.fromApi(json.str('status')),
  );

  FutureResult<void> accept(int callId) =>
      _client.send('POST', Api.callAccept(callId));

  FutureResult<void> reject(int callId) =>
      _client.send('POST', Api.callReject(callId));

  FutureResult<void> end(int callId) =>
      _client.send('POST', Api.callEnd(callId));

  FutureResult<CallCredentials> credentials(int callId) => _client.getObject(
    Api.callToken(callId),
    parse: CallCredentialsModel.fromJson,
  );

  FutureResult<void> registerVoipToken(String token) =>
      _client.send('POST', Api.meVoipTokens, body: {'token': token});
}
