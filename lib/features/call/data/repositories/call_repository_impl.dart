import '../../../../core/error/result.dart';
import '../../domain/entities/call.dart';
import '../../domain/repositories/call_repository.dart';
import '../services/call_api_service.dart';

class CallRepositoryImpl implements CallRepository {
  const CallRepositoryImpl(this._api);

  final CallApiService _api;

  @override
  FutureResult<Call> create(int receiverId) => _api.create(receiverId);

  @override
  FutureResult<CallStatus> status(int callId) => _api.status(callId);

  @override
  FutureResult<void> accept(int callId) => _api.accept(callId);

  @override
  FutureResult<void> reject(int callId) => _api.reject(callId);

  @override
  FutureResult<void> end(int callId) => _api.end(callId);

  @override
  FutureResult<CallCredentials> credentials(int callId) =>
      _api.credentials(callId);

  @override
  FutureResult<void> registerVoipToken(String token) =>
      _api.registerVoipToken(token);
}
