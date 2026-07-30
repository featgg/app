import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_widget_dto.dart';
import 'profile_widgets_data_source.dart';

final class SupabaseProfileWidgetsDataSource
    implements ProfileWidgetsDataSource {
  SupabaseProfileWidgetsDataSource(this._client);

  final SupabaseClient _client;

  static const _table = 'profile_widgets';
  static const _columns =
      'id, user_id, platform, type, position, is_enabled, settings, '
      'created_at, last_updated_at';

  @override
  Future<List<ProfileWidgetDto>> fetchMyWidgets(String userId) =>
      _selectByUser(userId);

  @override
  Future<List<ProfileWidgetDto>> fetchPublicWidgets(String userId) =>
      _selectByUser(userId);

  /// Shared `user_id`-scoped select for both the owner and public reads. The
  /// table is publicly readable for public profiles, so an unscoped select would
  /// also return foreign rows; filter by the owner.
  Future<List<ProfileWidgetDto>> _selectByUser(String userId) async {
    final rows = await _client
        .from(_table)
        .select(_columns)
        .eq('user_id', userId)
        .order('position');
    return (rows as List<dynamic>)
        .map(
          (r) => ProfileWidgetDto.fromJson(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
  }

  @override
  Future<ProfileWidgetDto> insertWidget(Map<String, dynamic> row) async {
    final inserted = await _client
        .from(_table)
        .insert(row)
        .select(_columns)
        .single();
    return ProfileWidgetDto.fromJson(inserted);
  }

  @override
  Future<void> deleteWidget(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }

  @override
  Future<void> updateWidget(String id, Map<String, dynamic> values) async {
    await _client.from(_table).update(values).eq('id', id);
  }
}
