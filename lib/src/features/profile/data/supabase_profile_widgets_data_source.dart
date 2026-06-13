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
  Future<List<ProfileWidgetDto>> fetchMyWidgets(String userId) async {
    // The table is publicly readable for public profiles, so an authenticated
    // unscoped select would also return foreign rows; filter by the owner.
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

  @override
  Future<void> updatePositions(
    List<({String id, int position})> updates,
  ) async {
    // `position` is unique per user, so a single sequential pass to the final
    // 0..n-1 values can transiently collide (e.g. moving a row onto a slot a
    // not-yet-moved row still holds) and fail the constraint mid-reorder,
    // leaving the order half-written. Live positions are always >= 0 but may be
    // SPARSE (delete does not compact remaining rows), so parking into a
    // positive offset can still hit a current slot. Park into the negative
    // range instead — disjoint from every current position regardless of
    // sparsity — then write the final positions. Neither pass ever holds two
    // rows at the same value.
    for (var i = 0; i < updates.length; i++) {
      await _client
          .from(_table)
          .update({'position': -1 - i}) // -1, -2, … : distinct, all < 0
          .eq('id', updates[i].id);
    }
    for (final update in updates) {
      await _client
          .from(_table)
          .update({'position': update.position})
          .eq('id', update.id);
    }
  }
}
