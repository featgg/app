import 'package:featgg/src/features/profile/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a ProfileEdit with valid defaults so each test isolates one field.
ProfileEdit _edit({
  String displayName = 'Valid Name',
  String? avatarUrl,
  String? bio,
}) => ProfileEdit(
  displayName: displayName,
  avatarUrl: avatarUrl,
  bio: bio,
  theme: ProfileTheme.classic,
  privacy: ProfilePrivacy.public,
);

void main() {
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

    test('flags an avatar URL that is not an absolute http(s) URL', () {
      expect(
        _edit(avatarUrl: 'ftp://example.com/a.png').validate(),
        contains(ProfileEditField.avatarUrl),
      );
      expect(
        _edit(avatarUrl: 'not a url').validate(),
        contains(ProfileEditField.avatarUrl),
      );
      // http, https, and a null (cleared) avatar pass.
      expect(
        _edit(avatarUrl: 'https://example.com/a.png').validate(),
        isNot(contains(ProfileEditField.avatarUrl)),
      );
      expect(
        _edit(avatarUrl: 'http://example.com/a.png').validate(),
        isNot(contains(ProfileEditField.avatarUrl)),
      );
      expect(
        _edit(avatarUrl: null).validate(),
        isNot(contains(ProfileEditField.avatarUrl)),
      );
    });
  });
}
