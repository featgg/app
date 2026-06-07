import 'package:supabase_flutter/supabase_flutter.dart';

import 'connection_dto.dart';
import 'connections_data_source.dart';
import 'link_account_dto.dart';

final class SupabaseConnectionsDataSource implements ConnectionsDataSource {
  SupabaseConnectionsDataSource(this._client);

  final SupabaseClient _client;

  static const _table = 'linked_accounts';
  static const _columns =
      'platform, status, last_sync_at, created_at, remote_id, metadata';

  @override
  Future<LinkSuccessDto> linkAccount(Map<String, dynamic> body) async {
    final response = await _client.functions
        .invoke('link-account', method: HttpMethod.post, body: body)
        .timeout(const Duration(seconds: 15));
    return LinkSuccessDto.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  @override
  Future<LinkSuccessDto> unlinkAccount(String wireValue) async {
    final response = await _client.functions
        .invoke(
          'unlink-account',
          method: HttpMethod.post,
          body: {'platform': wireValue},
        )
        .timeout(const Duration(seconds: 10));
    return LinkSuccessDto.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  @override
  Future<SyncResultDto> syncPlatform(String functionName) async {
    final response = await _client.functions
        .invoke(
          functionName,
          method: HttpMethod.post,
          body: <String, dynamic>{},
        )
        .timeout(const Duration(seconds: 30));
    return SyncResultDto.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  @override
  Future<List<ConnectionDto>> fetchConnections() async {
    final rows = await _client
        .from(_table)
        .select(_columns)
        .order('created_at');
    return (rows as List<dynamic>)
        .map((r) => ConnectionDto.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }
}
