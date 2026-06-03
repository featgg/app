import 'profile_dto.dart';

/// Thin seam over the Supabase SDK for the profiles table.
///
/// Extracted so tests can fake the SDK query chain without constructing real
/// network clients. The repository implementation is the only caller.
abstract interface class ProfileDataSource {
  /// Reads the signed-in user's profile row for [userId] as a [ProfileDto].
  /// Returns null when no row exists (maybeSingle semantics). Throwing on a
  /// transport or parse fault is the caller's single try/catch to map.
  Future<ProfileDto?> fetchProfileRow(String userId);
}
