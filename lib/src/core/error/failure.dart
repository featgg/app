import 'package:equatable/equatable.dart';

/// Base type for every expected failure that crosses a layer boundary as
/// the `Left` of an `Either<Failure, T>`.
///
/// A `Failure` carries a stable [code]/type for branching and an optional
/// developer/log-only [message] — never user-facing text. The presentation
/// layer maps a failure to a localized string.
sealed class Failure extends Equatable {
  const Failure({this.message, this.code});

  /// Developer/log-only detail. Never displayed to a user. May be null.
  final String? message;

  /// Stable machine token for this failure, when one applies (e.g. a
  /// server-operation error-code token). Null when no token applies.
  final String? code;

  /// Whether this failure is normal control flow (true) rather than an
  /// unexpected fault (false). Drives crash-reporter filtering downstream.
  bool get isExpected;

  @override
  List<Object?> get props => [message, code, isExpected];
}

/// A surface with no consumed brief. Returned by stub repository methods.
final class NotImplemented extends Failure {
  const NotImplemented({super.message, super.code});

  @override
  bool get isExpected => true;
}

/// A server operation returned a `success:false` envelope or non-2xx.
/// Carries the `code` token and `message`.
final class ServerFailure extends Failure {
  const ServerFailure({super.message, super.code});

  @override
  bool get isExpected => false;
}

/// Transport-level fault: no connection, DNS, TLS, timeout.
final class NetworkFailure extends Failure {
  const NetworkFailure({super.message, super.code});

  @override
  bool get isExpected => false;
}

/// Session invalid/expired (`UNAUTHORIZED` 401 class). Normal control flow —
/// drives re-auth, not crash-reported.
final class AuthFailure extends Failure {
  const AuthFailure({super.message, super.code});

  @override
  bool get isExpected => true;
}

/// Client/request validation rejected (`INVALID_REQUEST` 400 class).
/// Normal control flow.
final class InputFailure extends Failure {
  const InputFailure({super.message, super.code});

  @override
  bool get isExpected => true;
}

/// Auth send/verify was rate-limited (HTTP 429 class). Normal control flow:
/// the UI disables resend and backs off. Not crash-reported.
final class AuthRateLimitFailure extends Failure {
  const AuthRateLimitFailure({super.message, super.code});

  @override
  bool get isExpected => true;
}

/// Catch-all for anything the mapper cannot classify (DTO parse failure,
/// unhandled exception). Crash-reported.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure({super.message, super.code});

  @override
  bool get isExpected => false;
}
