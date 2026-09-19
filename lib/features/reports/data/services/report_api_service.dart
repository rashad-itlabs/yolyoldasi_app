import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/report.dart';

/// `POST /reports` — API.md §15.
class ReportApiService {
  const ReportApiService(this._client);

  final ApiClient _client;

  FutureResult<void> submit(ReportDraft draft) => _client.send(
    'POST',
    Api.reports,
    body: {
      'target_user_id': draft.targetUserId,
      'reason': draft.reason!.apiValue,
      'details': ?_blankToNull(draft.details),
      'ride_id': ?draft.rideId,
      'booking_id': ?draft.bookingId,
    },
  );

  static String? _blankToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
