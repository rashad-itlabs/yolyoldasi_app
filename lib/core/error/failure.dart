import 'package:equatable/equatable.dart';

/// Stable machine codes for every failure the domain can surface.
///
/// The presentation layer maps these to localized text, so failures never
/// carry user-facing strings across layers — except for [Failure.serverMessage],
/// which the API already returns in the caller's language.
enum FailureCode {
  network,
  timeout,
  server,
  unauthenticated,
  permissionDenied,
  notFound,
  alreadyExists,
  invalidInput,
  invalidPhoneNumber,
  invalidOtp,
  otpExpired,
  tooManyRequests,
  seatsUnavailable,
  rideNotBookable,
  bookingNotCancellable,
  selfBooking,
  documentsPending,
  documentsRejected,

  /// Driver mode asked for on an account with no car. `PUT /me/mode` answers
  /// 422 for it (API.md §4), and the profile screen turns it into an offer to
  /// add one rather than an error.
  driverProfileRequired,

  /// The ride takes women passengers only (API.md §21).
  womenOnlyRide,
  storage,
  cancelled,
  unknown,
}

/// Base type for anything that can go wrong in the domain layer.
sealed class Failure extends Equatable implements Exception {
  const Failure(this.code, {this.serverMessage, this.debugMessage, this.cause});

  final FailureCode code;

  /// The API's own `message` field. Laravel returns business-rule violations
  /// (`abort(422, '...')`) as prose in the user's language, and there is no
  /// machine code to map them to, so the client shows this verbatim when it is
  /// present. Never set for transport-level failures.
  final String? serverMessage;

  /// Developer-facing detail. Never shown to users.
  final String? debugMessage;
  final Object? cause;

  @override
  List<Object?> get props => [code, serverMessage, debugMessage];

  @override
  String toString() =>
      '$runtimeType(${code.name}${debugMessage == null ? '' : ': $debugMessage'})';
}

class NetworkFailure extends Failure {
  const NetworkFailure({super.debugMessage, super.cause})
    : super(FailureCode.network);
}

class TimeoutFailure extends Failure {
  const TimeoutFailure({super.debugMessage, super.cause})
    : super(FailureCode.timeout);
}

class ServerFailure extends Failure {
  const ServerFailure({super.serverMessage, super.debugMessage, super.cause})
    : super(FailureCode.server);
}

class AuthFailure extends Failure {
  const AuthFailure(
    super.code, {
    super.serverMessage,
    super.debugMessage,
    super.cause,
  });
}

/// A 429, with the wait the API asked for when it named one.
///
/// Two limiters guard the sign-in endpoints and they report the wait
/// differently: the app's own resend throttle puts `retry_after` seconds in the
/// body, while Laravel's `throttle` middleware sends only the `Retry-After`
/// header and a bare "Too Many Attempts." — see API.md §3. [ApiErrors] reads
/// whichever is present, so callers get one field instead of two shapes.
///
/// [retryAfter] is null when neither was given; treat that as "unknown", not
/// "no wait".
class RateLimitFailure extends Failure {
  const RateLimitFailure({
    this.retryAfter,
    super.serverMessage,
    super.debugMessage,
    super.cause,
  }) : super(FailureCode.tooManyRequests);

  final Duration? retryAfter;

  @override
  List<Object?> get props => [code, retryAfter, serverMessage, debugMessage];
}

class PermissionFailure extends Failure {
  const PermissionFailure({
    super.serverMessage,
    super.debugMessage,
    super.cause,
  }) : super(FailureCode.permissionDenied);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure({super.serverMessage, super.debugMessage, super.cause})
    : super(FailureCode.notFound);
}

/// A 409 from the API: the same booking or review was submitted twice.
///
/// Kept distinct from [ValidationFailure] because the booking flow has to tell
/// "you already applied to this ride" apart from "these fields are wrong" —
/// see API.md §10, where the 409 is permanent even after a cancellation.
class ConflictFailure extends Failure {
  const ConflictFailure({super.serverMessage, super.debugMessage, super.cause})
    : super(FailureCode.alreadyExists);
}

class ValidationFailure extends Failure {
  const ValidationFailure(
    super.code, {
    this.field,
    this.errors = const {},
    super.serverMessage,
    super.debugMessage,
    super.cause,
  });

  /// Which form field the failure belongs to, when applicable.
  final String? field;

  /// Laravel's `errors` map: field name to the messages for that field. Empty
  /// for business-rule 422s, which carry only [Failure.serverMessage].
  final Map<String, List<String>> errors;

  /// The first message recorded against [name], if any.
  String? messageFor(String name) {
    final messages = errors[name];
    return (messages == null || messages.isEmpty) ? null : messages.first;
  }

  @override
  List<Object?> get props => [code, field, errors, serverMessage, debugMessage];
}

/// Business-rule violations (seats gone, ride already started, ...).
class BusinessFailure extends Failure {
  const BusinessFailure(
    super.code, {
    super.serverMessage,
    super.debugMessage,
    super.cause,
  });
}

class StorageFailure extends Failure {
  const StorageFailure({super.debugMessage, super.cause})
    : super(FailureCode.storage);
}

class UnknownFailure extends Failure {
  const UnknownFailure({super.serverMessage, super.debugMessage, super.cause})
    : super(FailureCode.unknown);
}
