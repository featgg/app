import 'package:featgg/src/features/profile/data/profile_dto.dart';
import 'package:featgg/src/features/profile/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _fullRow({String privacyLevel = 'public'}) => {
  'id': 'user-123',
  'username': 'testuser',
  'display_name': 'Test User',
  'avatar_url': 'https://example.com/avatar.png',
  'bio': 'Hello world',
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
  });
}
