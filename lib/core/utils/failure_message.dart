import '../error/failure.dart';
import '../localization/app_strings.dart';

extension FailureMessage on Failure {
  /// Localized, user-facing text for this failure.
  ///
  /// The API's own `message` wins when there is one: API.md §1 notes that a
  /// business-rule 422 carries only prose (`abort(422, 'Bu səfər artıq
  /// başlayıb')`) with no machine code to map, and that prose is already in the
  /// user's language. Transport failures never set it, so they fall through to
  /// the local strings.
  String message(AppStrings strings) {
    final fromServer = serverMessage?.trim();
    if (fromServer != null && fromServer.isNotEmpty) return fromServer;
    if (this case UnknownFailure(:final statusCode?)) {
      return '${strings.byKey(_key)} ($statusCode)';
    }
    return strings.byKey(_key);
  }

  String get _key => switch (code) {
    FailureCode.network => 'errNetwork',
    FailureCode.timeout => 'errTimeout',
    FailureCode.server => 'errServer',
    FailureCode.unauthenticated => 'errUnauthenticated',
    FailureCode.permissionDenied => 'errPermissionDenied',
    FailureCode.notFound => 'errNotFound',
    FailureCode.alreadyExists => 'errAlreadyExists',
    FailureCode.invalidInput => 'errInvalidInput',
    FailureCode.invalidPhoneNumber => 'errInvalidPhoneNumber',
    FailureCode.invalidOtp => 'errInvalidOtp',
    FailureCode.otpExpired => 'errOtpExpired',
    FailureCode.tooManyRequests => 'errTooManyRequests',
    FailureCode.seatsUnavailable => 'errSeatsUnavailable',
    FailureCode.rideNotBookable => 'errRideNotBookable',
    FailureCode.bookingNotCancellable => 'errBookingNotCancellable',
    FailureCode.selfBooking => 'errSelfBooking',
    FailureCode.documentsPending => 'errDocumentsPending',
    FailureCode.documentsRejected => 'errDocumentsRejected',
    FailureCode.driverProfileRequired => 'errDriverProfileRequired',
    FailureCode.womenOnlyRide => 'errWomenOnlyRide',
    FailureCode.fileTooLarge => 'errFileTooLarge',
    FailureCode.storage => 'errStorage',
    FailureCode.cancelled => 'errCancelled',
    FailureCode.unknown => 'errUnknown',
  };

  /// Whether offering a "retry" button makes sense for this failure.
  bool get isRetryable => switch (code) {
    FailureCode.network ||
    FailureCode.timeout ||
    FailureCode.server ||
    FailureCode.unknown => true,
    _ => false,
  };

  /// A 409 on `POST /rides/{id}/bookings` means "you already applied to this
  /// ride", and API.md §16.4 asks for that to read differently from a generic
  /// duplicate. The booking bloc checks this before showing [message].
  bool get isDuplicate => this is ConflictFailure;
}
