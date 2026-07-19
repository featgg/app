import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_data_source.dart';
import 'profile_dto.dart';

final class SupabaseProfileDataSource implements ProfileDataSource {
  SupabaseProfileDataSource(this._client);

  final SupabaseClient _client;

  static const _table = 'profiles';
  static const _columns =
      'id, username, display_name, avatar_url, bio, theme_id, privacy_level, featured_platform, layout';

  // deletion_requested_at is an owner-only, server-managed column. It must never
  // be requested on a public read of another user's row, so it is appended only
  // for the owner's own read.
  static const _ownerColumns = '$_columns, deletion_requested_at';

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

  @override
  Future<ProfileDto?> fetchMyProfileRow(String userId) async {
    final row = await _client
        .from(_table)
        .select(_ownerColumns)
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return ProfileDto.fromJson(row);
  }

  @override
  Future<ProfileDto> updateProfileRow(
    String userId,
    Map<String, dynamic> values,
  ) async {
    // .single() — an update of the owner's own row must return exactly one row;
    // zero rows is a fault that the caller's try/catch maps to UnexpectedFailure.
    final row = await _client
        .from(_table)
        .update(values)
        .eq('id', userId)
        .select(_ownerColumns)
        .single();
    return ProfileDto.fromJson(row);
  }
}
