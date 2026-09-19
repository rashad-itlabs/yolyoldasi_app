import 'failure.dart';

/// A lightweight `Either`-style result used by every repository method.
///
/// Chosen over exceptions so callers are forced to acknowledge the failure
/// path, and over `dartz` so the codebase keeps zero functional-programming
/// ceremony.
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;
  const factory Result.err(Failure failure) = Err<T>;

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  /// The value, or `null` when this is an [Err].
  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  /// The failure, or `null` when this is an [Ok].
  Failure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final failure) => failure,
  };

  /// Throws the failure when this is an [Err]. Use only where a throw is
  /// genuinely wanted — blocs fold instead, so a failure becomes an error
  /// *state* rather than an unhandled exception.
  T unwrap() => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>(:final failure) => throw failure,
  };

  R fold<R>(R Function(T value) onOk, R Function(Failure failure) onErr) =>
      switch (this) {
        Ok<T>(:final value) => onOk(value),
        Err<T>(:final failure) => onErr(failure),
      };

  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T>(:final value) => Ok<R>(transform(value)),
    Err<T>(:final failure) => Err<R>(failure),
  };

  Future<Result<R>> mapAsync<R>(Future<R> Function(T value) transform) async =>
      switch (this) {
        Ok<T>(:final value) => Ok<R>(await transform(value)),
        Err<T>(:final failure) => Err<R>(failure),
      };

  Result<R> flatMap<R>(Result<R> Function(T value) transform) => switch (this) {
    Ok<T>(:final value) => transform(value),
    Err<T>(:final failure) => Err<R>(failure),
  };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Ok<T> && other.value == value);

  @override
  int get hashCode => Object.hash(Ok, value);

  @override
  String toString() => 'Ok($value)';
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Err<T> && other.failure == failure);

  @override
  int get hashCode => Object.hash(Err, failure);

  @override
  String toString() => 'Err($failure)';
}

/// Convenience alias used throughout the repositories.
typedef FutureResult<T> = Future<Result<T>>;

/// Runs [body] and converts any thrown object into a [Failure].
///
/// [onError] lets a data source translate its platform-specific exceptions
/// (e.g. `FirebaseException`) before the generic fallback kicks in.
Future<Result<T>> guard<T>(
  Future<T> Function() body, {
  Failure Function(Object error, StackTrace stackTrace)? onError,
}) async {
  try {
    return Ok(await body());
  } on Failure catch (f) {
    return Err(f);
  } catch (error, stackTrace) {
    return Err(
      onError?.call(error, stackTrace) ??
          UnknownFailure(debugMessage: error.toString(), cause: error),
    );
  }
}
