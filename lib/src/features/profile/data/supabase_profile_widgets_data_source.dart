import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_widget_dto.dart';
import 'profile_widgets_data_source.dart';

/// Pass 1 parks every row in a positive band strictly above [maxCurrentPosition]
/// (disjoint from every live position, which the backend guarantees is `>= 0`
/// and unique per user); pass 2 writes the final contiguous `0..n-1`. Returned
/// in application order: all parking writes, then all final writes.
List<({String id, int position})> reorderPositionWrites(
  List<({String id, int position})> updates,
  int maxCurrentPosition,
) {
  final base = maxCurrentPosition + 1;
  return [
    for (var i = 0; i < updates.length; i++)
      (id: updates[i].id, position: base + i), // park: > every live position
    ...updates, // final: contiguous 0..n-1 (already computed by the repo)
  ];
}

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

  @override
  Future<void> updatePositions(
    List<({String id, int position})> updates,
  ) async {
    if (updates.isEmpty) return;
    // `position` is unique per user and the backend guarantees it is `>= 0`, so
    // a single sequential pass to the final 0..n-1 values can transiently
    // collide (e.g. moving a row onto a slot a not-yet-moved row still holds)
    // and fail the constraint mid-reorder, leaving the order half-written. Live
    // positions may also be SPARSE (delete does not compact remaining rows), so
    // a fixed positive offset can still hit a current slot. Read the current
    // max once and park every row in a positive band strictly above it
    // (disjoint from every live position regardless of sparsity, and never
    // negative), then write the final positions. Neither pass ever holds two
    // rows at the same value, and a pass-1-only failure leaves rows in the high
    // positive band — still legal — so the next reorder self-heals.
    final maxRow = await _client
        .from(_table)
        .select('position')
        .order('position', ascending: false)
        .limit(1)
        .maybeSingle();
    final maxCurrent = maxRow == null ? -1 : maxRow['position'] as int;
    final writes = reorderPositionWrites(updates, maxCurrent);
    for (final write in writes) {
      await _client
          .from(_table)
          .update({'position': write.position})
          .eq('id', write.id);
    }
  }
}
