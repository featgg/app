import 'package:supabase_flutter/supabase_flutter.dart';

import 'cards_data_source.dart';
import 'game_card_dto.dart';

final class SupabaseCardsDataSource implements CardsDataSource {
  SupabaseCardsDataSource(this._client);

  final SupabaseClient _client;

  static const _table = 'game_cards';

  @override
  Future<GameCardDto?> fetchCard(
    String userId,
    String platformWireValue,
  ) async {
    final row = await _client
        .from(_table)
        .select('platform, widget_data, last_updated_at')
        .eq('user_id', userId)
        .eq('platform', platformWireValue)
        .maybeSingle();
    if (row == null) return null;
    final widgetData = row['widget_data'];
    if (widgetData == null) return null;
    final map = Map<String, dynamic>.from(widgetData as Map);
    // Hard-code against v1; fall back to card-unavailable for any other
    // version. A bumped schema version signals a breaking change, so the
    // strict v1 envelope parse below cannot be trusted for it.
    if (map['schema_version'] != 1) return null;
    return GameCardDto.fromJson(map);
  }
}
