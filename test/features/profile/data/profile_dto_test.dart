import 'package:featgg/src/features/profile/data/profile_dto.dart';
import 'package:featgg/src/features/profile/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _fullRow({
  String privacyLevel = 'public',
  String themeId = 'classic',
}) => {
  'id': 'user-123',
  'username': 'testuser',
  'display_name': 'Test User',
  'avatar_url': 'https://example.com/avatar.png',
  'bio': 'Hello world',
  'theme_id': themeId,
  'privacy_level': privacyLevel,
};

void main() {
  group('ProfileDto.fromJson + profileFromDto', () {
    test('maps a full wire row to a Profile', () {
      final dto = ProfileDto.fromJson(_fullRow());
      final profile = profileFromDto(dto);

      expect(profile.id, 'user-123');
      expect(profile.username, 'testuser');
      expect(profile.displayName, 'Test User');
      expect(profile.avatarUrl, 'https://example.com/avatar.png');
      expect(profile.bio, 'Hello world');
      expect(profile.privacy, ProfilePrivacy.public);
      expect(profile.theme, ProfileTheme.classic);
    });

    test('privacy_level "private" maps to ProfilePrivacy.private', () {
      final dto = ProfileDto.fromJson(_fullRow(privacyLevel: 'private'));
      final profile = profileFromDto(dto);

      expect(profile.privacy, ProfilePrivacy.private);
    });

    test('null avatar_url and bio map to null', () {
      final row = {
        'id': 'user-456',
        'username': 'noavatar',
        'display_name': 'No Avatar',
        'avatar_url': null,
        'bio': null,
        'theme_id': 'classic',
        'privacy_level': 'public',
      };
      final profile = profileFromDto(ProfileDto.fromJson(row));

      expect(profile.avatarUrl, isNull);
      expect(profile.bio, isNull);
    });

    test('an unknown privacy_level throws FormatException', () {
      final dto = ProfileDto.fromJson(_fullRow(privacyLevel: 'restricted'));

      expect(() => profileFromDto(dto), throwsA(isA<FormatException>()));
    });

    // New tests for theme_id mapping.

    test('maps each theme_id wire token to the matching ProfileTheme', () {
      for (final entry in {
        'classic': ProfileTheme.classic,
        'immersive': ProfileTheme.immersive,
        'retro': ProfileTheme.retro,
        'analyst': ProfileTheme.analyst,
      }.entries) {
        final dto = ProfileDto.fromJson(_fullRow(themeId: entry.key));
        final profile = profileFromDto(dto);
        expect(
          profile.theme,
          entry.value,
          reason: 'theme_id "${entry.key}" should map to ${entry.value}',
        );
      }
    });

    test('an unknown theme_id throws FormatException', () {
      final dto = ProfileDto.fromJson(_fullRow(themeId: 'neon'));

      expect(() => profileFromDto(dto), throwsA(isA<FormatException>()));
    });

    test('profileEditToColumns builds the writable columns', () {
      const edit = ProfileEdit(
        displayName: 'Alice',
        bio: 'Hello',
        theme: ProfileTheme.retro,
        privacy: ProfilePrivacy.private,
      );
      final columns = profileEditToColumns(edit);

      expect(
        columns.keys,
        containsAll(['display_name', 'bio', 'theme_id', 'privacy_level']),
      );
      expect(columns['display_name'], 'Alice');
      expect(columns['bio'], 'Hello');
      expect(columns['theme_id'], 'retro');
      expect(columns['privacy_level'], 'private');

      // avatar_url is server-managed (set by the avatar-upload endpoint), so an
      // update must never write it; username and other server-managed columns
      // must also be absent.
      expect(columns.containsKey('avatar_url'), isFalse);
      expect(columns.containsKey('username'), isFalse);
      expect(columns.containsKey('id'), isFalse);
    });
  });
}
