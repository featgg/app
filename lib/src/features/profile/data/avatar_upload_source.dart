import 'dart:typed_data';

import 'avatar_dto.dart';

/// Thin seam over the Supabase Functions SDK for the avatar upload endpoint.
///
/// Extracted so the repository implementation can be exercised against a
/// hand-rolled fake without constructing real network clients.
/// Internal to the data layer — not exported beyond it.
abstract interface class AvatarUploadSource {
  /// Posts [bytes] with [contentType] to the moderation endpoint and returns
  /// the parsed success envelope. Throws [FunctionException] on non-2xx.
  Future<AvatarUploadDto> uploadAvatar(Uint8List bytes, String contentType);
}
