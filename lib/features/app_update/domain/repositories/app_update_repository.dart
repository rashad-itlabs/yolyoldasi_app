import '../../../../core/error/result.dart';
import '../entities/app_update.dart';

/// Asks the server whether this build is still allowed to run.
abstract interface class AppUpdateRepository {
  /// `GET /app-version`. Public, so it answers before sign-in — which is the
  /// point: a blocked build must not be able to reach the login screen.
  ///
  /// Returns an [Err] on any network or parse trouble. The bloc turns that
  /// into [AppUpdate.none] — the rule lives in exactly one place, because a
  /// call site that got it wrong would lock people out of a working app.
  FutureResult<AppUpdate> check();
}
