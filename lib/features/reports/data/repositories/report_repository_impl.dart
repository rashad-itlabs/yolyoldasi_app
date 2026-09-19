import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/report.dart';
import '../../domain/repositories/report_repository.dart';
import '../services/report_api_service.dart';

class ReportRepositoryImpl implements ReportRepository {
  const ReportRepositoryImpl(this._api);

  final ReportApiService _api;

  @override
  FutureResult<void> submit(ReportDraft draft) {
    // The service dereferences `reason`, so an incomplete draft is caught here
    // rather than throwing on the way to the wire.
    if (!draft.isValid) {
      return Future.value(
        const Err(ValidationFailure(FailureCode.invalidInput, field: 'reason')),
      );
    }
    return _api.submit(draft);
  }
}
