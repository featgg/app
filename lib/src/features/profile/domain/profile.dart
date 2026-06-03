import 'package:equatable/equatable.dart';

/// Whether the signed-in user's profile is publicly discoverable.
enum ProfilePrivacy { public, private }

/// The signed-in user's own identity as read from the profiles table.
final class Profile extends Equatable {
  const Profile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.bio,
    required this.privacy,
  });

  final String id;
  final String username;
  final String displayName;

  /// Absolute http/https avatar URL, or null when the user has none.
  final String? avatarUrl;

  /// Free-text bio (≤150 chars per the brief), or null when unset.
  final String? bio;

  final ProfilePrivacy privacy;

  @override
  List<Object?> get props => [
    id,
    username,
    displayName,
    avatarUrl,
    bio,
    privacy,
  ];
}
