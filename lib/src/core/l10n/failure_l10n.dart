import '../error/failure.dart';
import 'generated/app_localizations.dart';

/// Maps a [Failure] to user-facing, localized copy.
///
/// The presentation layer renders this string; a [Failure] itself never
/// carries user text. Exhaustive over the sealed subtypes — adding a new
/// [Failure] subtype is a compile error here until copy is supplied.
extension FailureL10n on Failure {
  String localizedMessage(AppLocalizations l10n) => switch (this) {
    NetworkFailure() => l10n.errorNetwork,
    ServerFailure() => l10n.errorServer,
    AuthFailure() => l10n.errorAuth,
    AuthRateLimitFailure() => l10n.errorAuthRateLimited,
    InputFailure() => l10n.errorInput,
    NotImplemented() => l10n.errorNotImplemented,
    UnexpectedFailure() => l10n.errorUnexpected,
    ModerationRejectedFailure() => l10n.errorAvatarRejected,
    ModerationUnavailableFailure() => l10n.errorAvatarUnavailable,
    RateLimitFailure() => l10n.errorAvatarRateLimited,
    MediaProcessingFailure() => l10n.errorAvatarProcessing,
    AlreadyLinkedFailure() => l10n.errorAlreadyLinked,
    SyncCooldownFailure() => l10n.errorSyncCooldown,
    UpstreamFailure(:final code) => switch (code) {
      'UPSTREAM_NOT_FOUND' => l10n.errorUpstreamNotFound,
      'LINKED_ACCOUNT_NOT_FOUND' => l10n.errorUpstreamNotConnected,
      'MISSING_STORED_CREDENTIAL' ||
      'INVALID_STORED_ROUTING' => l10n.errorUpstreamReconnect,
      _ => l10n.errorUpstream,
    },
  };
}
