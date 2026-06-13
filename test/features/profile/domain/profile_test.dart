import 'package:featgg/src/features/profile/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a ProfileEdit with valid defaults so each test isolates one field.
ProfileEdit _edit({String displayName = 'Valid Name', String? bio}) =>
    ProfileEdit(
      displayName: displayName,
      bio: bio,
      theme: ProfileTheme.classic,
      privacy: ProfilePrivacy.public,
      featuredPlatform: null,
    );

Profile _profile({DateTime? deletionRequestedAt}) => Profile(
  id: 'user-1',
  username: 'user',
  displayName: 'User',
  avatarUrl: null,
  bio: null,
  theme: ProfileTheme.classic,
  privacy: ProfilePrivacy.public,
  featuredPlatform: null,
  deletionRequestedAt: deletionRequestedAt,
);

void main() {
  group('Profile deletion markers', () {
    test('a null marker is not pending and has no scheduled target', () {
      final profile = _profile();
      expect(profile.isDeletionPending, isFalse);
      expect(profile.deletionScheduledAt, isNull);
    });

    test('a marker is pending and schedules 7 days out', () {
      final requestedAt = DateTime.utc(2026, 6, 12, 10);
      final profile = _profile(deletionRequestedAt: requestedAt);
      expect(profile.isDeletionPending, isTrue);
      expect(
        profile.deletionScheduledAt,
        requestedAt.add(const Duration(days: 7)),
      );
    });
  });

  group('ProfileEdit.validate — bio line breaks', () {
    test('flags a bio with more than 8 line breaks', () {
      // 9 breaks → flagged.
      expect(
        _edit(bio: '\n' * 9).validate(),
        contains(ProfileEditField.bioLineBreaks),
      );
      // 8 breaks → valid (boundary passes).
      expect(
        _edit(bio: '\n' * 8).validate(),
        isNot(contains(ProfileEditField.bioLineBreaks)),
      );
      // null → no flag.
      expect(
        _edit(bio: null).validate(),
        isNot(contains(ProfileEditField.bioLineBreaks)),
      );
      // Plain text without line breaks → no flag.
      expect(
        _edit(bio: 'plain text').validate(),
        isNot(contains(ProfileEditField.bioLineBreaks)),
      );
    });

    test(
      'bio that is both too long and has too many breaks flags both errors',
      () {
        // Build a bio that exceeds 150 chars and has more than 8 line breaks.
        final bio = '${'a' * 10}\n' * 15; // 15 lines, well over 150 chars.
        final errors = _edit(bio: bio).validate();
        expect(errors, contains(ProfileEditField.bio));
        expect(errors, contains(ProfileEditField.bioLineBreaks));
      },
    );
  });

  group('ProfileEdit.validate', () {
    test('flags a display name outside 1-50 characters', () {
      // Empty, whitespace-only, and over the upper bound are all rejected.
      expect(
        _edit(displayName: '').validate(),
        contains(ProfileEditField.displayName),
      );
      expect(
        _edit(displayName: '   ').validate(),
        contains(ProfileEditField.displayName),
      );
      expect(
        _edit(displayName: 'a' * 51).validate(),
        contains(ProfileEditField.displayName),
      );
      // The 1- and 50-char boundaries pass.
      expect(
        _edit(displayName: 'a').validate(),
        isNot(contains(ProfileEditField.displayName)),
      );
      expect(
        _edit(displayName: 'a' * 50).validate(),
        isNot(contains(ProfileEditField.displayName)),
      );
    });

    test('flags a bio longer than 150 characters', () {
      expect(_edit(bio: 'a' * 151).validate(), contains(ProfileEditField.bio));
      // The 150-char boundary and a null (cleared) bio pass.
      expect(
        _edit(bio: 'a' * 150).validate(),
        isNot(contains(ProfileEditField.bio)),
      );
      expect(
        _edit(bio: null).validate(),
        isNot(contains(ProfileEditField.bio)),
      );
    });
  });
}
