import 'package:equatable/equatable.dart';

import '../../connections/domain/connection.dart';
import 'profile_layout.dart';

/// Maximum line breaks allowed in a bio. Keeps a creative bio from pushing the
/// profile's cards far down the screen. Enforced both as input prevention on the
/// edit field and as a validation backstop here.
const int kMaxBioLineBreaks = 8;

/// Whether the signed-in user's profile is publicly discoverable.
enum ProfilePrivacy { public, private }

/// Visual theme the user has chosen for their profile. The enum name is the
/// `theme_id` wire token from the profile API's closed theme list.
enum ProfileTheme { crimson, ember, solar, chak, frost, abyss, arcane, rose }

/// The signed-in user's own identity as read from the profiles table.
final class Profile extends Equatable {
  const Profile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.bio,
    required this.theme,
    required this.privacy,
    required this.featuredPlatform,
    this.deletionRequestedAt,
    this.layout = const [],
    this.createdAt,
  });

  final String id;
  final String username;
  final String displayName;

  /// Absolute http/https avatar URL, or null when the user has none.
  final String? avatarUrl;

  /// Free-text bio (≤150 chars per the brief), or null when unset.
  final String? bio;

  final ProfileTheme theme;
  final ProfilePrivacy privacy;

  /// The platform card the user has pinned as their discovery-feed preview,
  /// or null to use the default (most-recently-updated card).
  final Platform? featuredPlatform;

  /// Server-managed read-only marker set when a deletion is pending, or null
  /// when none is. The client reads but never writes it.
  final DateTime? deletionRequestedAt;

  /// The composed profile layout: an ordered list of rows referencing this
  /// profile's own widget ids (see `docs/personalization/spec.md` §9).
  /// Server-managed and read-only to the client; empty for every profile that
  /// has no composed layout, in which case the legacy render path is used.
  final List<ProfileLayoutRow> layout;

  /// When the profile was created (server-managed). Feeds member-since
  /// displays; null when the read surface did not include it.
  final DateTime? createdAt;

  /// Grace window the backend applies after a confirmed deletion request.
  static const Duration deletionGracePeriod = Duration(days: 7);

  /// Whether a deletion is pending for this account.
  bool get isDeletionPending => deletionRequestedAt != null;

  /// The 7-day deletion target, or null when no deletion is pending.
  DateTime? get deletionScheduledAt =>
      deletionRequestedAt?.add(deletionGracePeriod);

  Profile copyWith({
    String? displayName,
    // Wrapped in a nullary function so callers can explicitly set null.
    String? Function()? avatarUrl,
    String? Function()? bio,
    ProfileTheme? theme,
    ProfilePrivacy? privacy,
    Platform? Function()? featuredPlatform,
    DateTime? Function()? deletionRequestedAt,
  }) => Profile(
    id: id,
    username: username,
    displayName: displayName ?? this.displayName,
    avatarUrl: avatarUrl != null ? avatarUrl() : this.avatarUrl,
    bio: bio != null ? bio() : this.bio,
    theme: theme ?? this.theme,
    privacy: privacy ?? this.privacy,
    featuredPlatform: featuredPlatform != null
        ? featuredPlatform()
        : this.featuredPlatform,
    deletionRequestedAt: deletionRequestedAt != null
        ? deletionRequestedAt()
        : this.deletionRequestedAt,
  );

  @override
  List<Object?> get props => [
    id,
    username,
    displayName,
    avatarUrl,
    bio,
    theme,
    privacy,
    featuredPlatform,
    deletionRequestedAt,
    layout,
    createdAt,
  ];
}

/// Writable fields for an update (the documented writable columns, minus
/// username and avatar_url, which is server-managed via the upload endpoint).
final class ProfileEdit extends Equatable {
  const ProfileEdit({
    required this.displayName,
    required this.bio,
    required this.theme,
    required this.privacy,
    required this.featuredPlatform,
  });

  final String displayName;
  final String? bio;
  final ProfileTheme theme;
  final ProfilePrivacy privacy;

  /// The platform card to pin as the discovery-feed preview, or null to use
  /// the default (most-recently-updated card).
  final Platform? featuredPlatform;

  /// Pure client-side validation mirroring the documented constraints.
  /// Returns the per-field errors found, empty when the edit is valid.
  /// UX feedback only; the backend remains authoritative.
  Set<ProfileEditField> validate() {
    final errors = <ProfileEditField>{};

    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty || trimmedName.length > 50) {
      errors.add(ProfileEditField.displayName);
    }

    if (bio != null && bio!.length > 150) {
      errors.add(ProfileEditField.bio);
    }

    if (bio != null && '\n'.allMatches(bio!).length > kMaxBioLineBreaks) {
      errors.add(ProfileEditField.bioLineBreaks);
    }

    return errors;
  }

  @override
  List<Object?> get props => [
    displayName,
    bio,
    theme,
    privacy,
    featuredPlatform,
  ];
}

/// Which field failed client validation; the screen maps each to localized copy.
enum ProfileEditField { displayName, bio, bioLineBreaks }
