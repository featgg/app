import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'avatar_dto.dart';
import 'avatar_upload_source.dart';

final class SupabaseAvatarUploadSource implements AvatarUploadSource {
  SupabaseAvatarUploadSource(this._client);

  final SupabaseClient _client;

  @override
  Future<AvatarUploadDto> uploadAvatar(
    Uint8List bytes,
    String contentType,
  ) async {
    final res = await _client.functions
        .invoke(
          'moderate-and-set-avatar',
          method: HttpMethod.post,
          headers: {'Content-Type': contentType},
          body: bytes,
        )
        .timeout(const Duration(seconds: 30));
    return AvatarUploadDto.fromJson(res.data as Map<String, dynamic>);
  }
}
