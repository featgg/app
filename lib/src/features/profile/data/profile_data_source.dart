import 'profile_dto.dart';

/// Thin seam over the Supabase SDK for the profiles table.
///
/// Extracted so tests can fake the SDK query chain without constructing real
/// network clients. The repository implementation is the only caller.
abstract interface class ProfileDataSource {
  /// Reads a profile row for [userId] as a [ProfileDto]. The single row read:
  /// used for the signed-in user's own profile and for any other user's public
  /// profile alike. Returns null when no row exists (maybeSingle semantics).
  /// Throwing on a transport or parse fault is the caller's single try/catch to
  /// map.
  Future<ProfileDto?> fetchProfileRow(String userId);

  /// Writes [values] (the writable columns) to the signed-in user's row and
  /// returns the updated row as a DTO. Throws on transport or parse fault for
  /// the caller's single try/catch to map.
  Future<ProfileDto> updateProfileRow(
    String userId,
    Map<String, dynamic> values,
  );

  /// Persists the caller's own composition via the owner-scoped write path,
  /// replacing the whole layout with [rows] (an empty list clears it). Throws on
  /// a transport or validation fault for the caller's single try/catch to map.
  Future<void> saveLayout(List<Map<String, dynamic>> rows);
}
