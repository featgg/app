import 'package:equatable/equatable.dart';

import '../../connections/domain/connection.dart';

/// Whether the signed-in user's profile is publicly discoverable.
enum ProfilePrivacy { public, private }

/// Visual theme the user has chosen for their profile.
enum ProfileTheme { classic, immersive, retro, analyst }

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

  Profile copyWith({
    String? displayName,
    // Wrapped in a nullary function so callers can explicitly set null.
    String? Function()? avatarUrl,
    String? Function()? bio,
    ProfileTheme? theme,
    ProfilePrivacy? privacy,
    Platform? Function()? featuredPlatform,
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
enum ProfileEditField { displayName, bio }
