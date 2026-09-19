import '../../../../core/error/result.dart';
import '../entities/report.dart';

/// Filing a complaint about another user — API.md §15.
///
/// Write-only: the API offers no endpoint to read reports back, so there is
/// nothing to list or track on the client.
abstract interface class ReportRepository {
  /// Callers must check [ReportDraft.isValid] first; the API answers 422 for a
  /// missing reason, missing details on `other`, or reporting yourself.
  FutureResult<void> submit(ReportDraft draft);
}
