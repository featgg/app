import 'profile_dto.dart';

/// Thin seam over the Supabase SDK for the profiles table.
///
/// Extracted so tests can fake the SDK query chain without constructing real
/// network clients. The repository implementation is the only caller.
abstract interface class ProfileDataSource {
  /// Reads a profile row for [userId] as a [ProfileDto], requesting only the
  /// publicly-readable columns. Used for reading any user's profile (including
  /// other users' public profiles); it must not request owner-only columns.
  /// Returns null when no row exists (maybeSingle semantics). Throwing on a
  /// transport or parse fault is the caller's single try/catch to map.
  Future<ProfileDto?> fetchProfileRow(String userId);

  /// Reads the signed-in owner's own profile row for [userId] as a [ProfileDto],
  /// including owner-only server-managed columns (the deletion marker). Only the
  /// owner reading their own row may request these columns. Returns null when no
  /// row exists. Throwing on a transport or parse fault is the caller's single
  /// try/catch to map.
  Future<ProfileDto?> fetchMyProfileRow(String userId);

  /// Writes [values] (the writable columns) to the signed-in user's row and
  /// returns the updated row as a DTO. Throws on transport or parse fault for
  /// the caller's single try/catch to map.
  Future<ProfileDto> updateProfileRow(
    String userId,
    Map<String, dynamic> values,
  );
}
