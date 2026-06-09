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

/// Transport-level: no connection, DNS, TLS, timeout. Normal control flow —
/// offline/transport is the user's environment, not an app fault.
/// Not crash-reported.
final class NetworkFailure extends Failure {
  const NetworkFailure({super.message, super.code});

  @override
  bool get isExpected => true;
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

/// The avatar moderation provider flagged the image content. Expected control
/// flow — the user can pick a different image. Not crash-reported.
/// [categories] contains the flagged category tokens from the server; they are
/// never shown to the user directly.
final class ModerationRejectedFailure extends Failure {
  const ModerationRejectedFailure({
    this.categories = const [],
    super.message,
    super.code,
  });

  final List<String> categories;

  @override
  bool get isExpected => true;

  @override
  List<Object?> get props => [...super.props, categories];
}

/// The moderation provider was unavailable or returned an unexpected error.
/// Not expected control flow — worth a crash report so outages are visible.
final class ModerationUnavailableFailure extends Failure {
  const ModerationUnavailableFailure({super.message, super.code});

  @override
  bool get isExpected => false;
}

/// A rate-limited server operation (HTTP 429 class). Expected control flow:
/// the UI surfaces a "try again shortly" message and the user may retry.
final class RateLimitFailure extends Failure {
  const RateLimitFailure({super.message, super.code});

  @override
  bool get isExpected => true;
}

/// A local image decode/crop step failed before any upload (the bytes could
/// not be decoded, or the in-app cropper reported a failure). Expected control
/// flow — distinct from a user cancel, which stays idle. Not crash-reported:
/// a corrupt/unsupported local file is the user's input, not an app fault.
final class MediaProcessingFailure extends Failure {
  const MediaProcessingFailure({super.message, super.code});

  @override
  bool get isExpected => true;
}

/// A connection already exists for this platform (`ALREADY_LINKED` 409).
/// Expected control flow — the link controller treats it as success-equivalent
/// at the repository boundary; this subtype exists so a future "already
/// connected" surface can branch on it without re-deriving the code.
final class AlreadyLinkedFailure extends Failure {
  const AlreadyLinkedFailure({super.message, super.code});

  @override
  bool get isExpected => true;
}

/// A refresh hit the per-connection cooldown (`SYNC_COOLDOWN` / `REFRESH_COOLDOWN`
/// 429). Expected control flow — drives a disabled-refresh state in the UI.
/// The server window is authoritative; the client applies a fixed proactive
/// cooldown as a UX affordance only.
final class SyncCooldownFailure extends Failure {
  const SyncCooldownFailure({
    super.message,
    super.code,
    this.retryAfterSeconds,
  });

  /// Server-provided remaining cooldown seconds, when the response body
  /// carried `retry_after`; null when absent (caller applies its fallback).
  final int? retryAfterSeconds;

  @override
  bool get isExpected => true;

  @override
  List<Object?> get props => [...super.props, retryAfterSeconds];
}

/// An upstream third-party platform is unavailable, not-found, or rate-limited,
/// or the stored connection routing is broken (`UPSTREAM_*`,
/// `LINKED_ACCOUNT_NOT_FOUND`, `MISSING_STORED_CREDENTIAL`,
/// `INVALID_STORED_ROUTING`). Expected control flow — the user retries or
/// reconnects; not an app fault. Not crash-reported.
final class UpstreamFailure extends Failure {
  const UpstreamFailure({super.message, super.code});

  @override
  bool get isExpected => true;
}
