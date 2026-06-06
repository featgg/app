import 'link_account_dto.dart';
import 'connection_dto.dart';

/// Thin seam over the Supabase SDK for Shape-1 edge-function calls and the
/// Shape-2 `linked_accounts` read. Extracted so tests can fake the SDK without
/// constructing real network clients. The repository is the only caller.
abstract interface class ConnectionsDataSource {
  /// Calls `link-account` with [body]. Returns the success DTO on 200.
  /// Throws on any non-2xx or transport fault (the repo's single try/catch maps
  /// it).
  Future<LinkSuccessDto> linkAccount(Map<String, dynamic> body);

  /// Calls `unlink-account` with `{platform: wireValue}`. Returns the success
  /// DTO on 200. Throws on failure.
  Future<LinkSuccessDto> unlinkAccount(String wireValue);

  /// Calls `sync-<platform>` (derived from [functionName]). Returns the sync
  /// result DTO on 200. Throws on failure.
  Future<SyncResultDto> syncPlatform(String functionName);

  /// Reads all `linked_accounts` rows for the caller ordered by `created_at`.
  /// Owner-only RLS scopes the result server-side; no client-side user filter.
  Future<List<ConnectionDto>> fetchConnections();
}
