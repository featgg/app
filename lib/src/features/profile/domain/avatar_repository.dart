import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../core/error/failure.dart';

abstract interface class AvatarRepository {
  /// Uploads [bytes] (a cropped/compressed image of [contentType], one of
  /// image/jpeg, image/png, or image/webp) to the moderation endpoint and
  /// returns the new public avatar URL on success.
  ///
  /// Left([ModerationRejectedFailure]) when content is flagged (carries
  /// categories); Left([InputFailure]) on 413/415; Left([AuthFailure]) on 401;
  /// Left([RateLimitFailure]) on 429 (per-user upload cooldown);
  /// Left([ModerationUnavailableFailure]) on provider error/timeout (fail
  /// closed); Left([MediaProcessingFailure]) on a local decode/crop fault
  /// (produced by the picker layer, not the repository itself);
  /// Left([NetworkFailure]) on transport error;
  /// Left([UnexpectedFailure]) otherwise.
  Future<Either<Failure, String>> uploadAvatar({
    required Uint8List bytes,
    required String contentType,
  });
}
