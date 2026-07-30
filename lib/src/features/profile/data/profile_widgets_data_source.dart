import 'profile_widget_dto.dart';

/// Thin seam over the Supabase SDK for the Shape-2 `profile_widgets` access.
/// Extracted so tests can fake the SDK without constructing real network
/// clients. The repository is the only caller. Each method throws on transport
/// or parse fault for the repo's single try/catch.
abstract interface class ProfileWidgetsDataSource {
  /// Returns the owner's widget rows ordered by `position`. [userId] scopes the
  /// read to the owner — the table is publicly readable for public profiles, so
  /// an unscoped select would also return foreign rows.
  Future<List<ProfileWidgetDto>> fetchMyWidgets(String userId);

  /// Returns any user's widget rows ordered by `position` for the public visitor
  /// render. [userId] scopes the read to that profile. The query is the same
  /// `user_id`-scoped select as [fetchMyWidgets]; this method exists so the
  /// repository can expose a public read with no auth gate (RLS returns no rows
  /// for a private profile).
  Future<List<ProfileWidgetDto>> fetchPublicWidgets(String userId);

  /// Inserts a widget [row] (writable columns only) and returns the new row.
  Future<ProfileWidgetDto> insertWidget(Map<String, dynamic> row);

  /// Deletes the owner's widget [id].
  Future<void> deleteWidget(String id);

  /// Updates writable [values] on the owner's widget [id].
  Future<void> updateWidget(String id, Map<String, dynamic> values);
}
