import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_data_source.dart';
import 'profile_dto.dart';

final class SupabaseProfileDataSource implements ProfileDataSource {
  SupabaseProfileDataSource(this._client);

  final SupabaseClient _client;

  static const _table = 'profiles';
  static const _columns =
      'id, username, display_name, avatar_url, bio, privacy_level';

  @override
  Future<ProfileDto?> fetchProfileRow(String userId) async {
    final row = await _client
        .from(_table)
        .select(_columns)
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return ProfileDto.fromJson(row);
  }
}
