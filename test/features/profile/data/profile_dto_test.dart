import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/profile/data/profile_dto.dart';
import 'package:featgg/src/features/profile/domain/profile.dart';
import 'package:featgg/src/features/profile/domain/profile_layout.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _fullRow({
  String privacyLevel = 'public',
  String themeId = 'crimson',
  Object? featuredPlatform,
  Object? deletionRequestedAt,
  List<dynamic>? layout,
  Object? createdAt,
}) => {
  'id': 'user-123',
  'username': 'testuser',
  'display_name': 'Test User',
  'avatar_url': 'https://example.com/avatar.png',
  'bio': 'Hello world',
  'theme_id': themeId,
  'privacy_level': privacyLevel,
  'featured_platform': featuredPlatform,
  'deletion_requested_at': deletionRequestedAt,
  'layout': ?layout,
  'created_at': ?createdAt,
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
      expect(profile.theme, ProfileTheme.crimson);
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
        'theme_id': 'crimson',
        'privacy_level': 'public',
        'featured_platform': null,
      };
      final profile = profileFromDto(ProfileDto.fromJson(row));

      expect(profile.avatarUrl, isNull);
      expect(profile.bio, isNull);
    });

    test('an unknown privacy_level throws FormatException', () {
      final dto = ProfileDto.fromJson(_fullRow(privacyLevel: 'restricted'));

      expect(() => profileFromDto(dto), throwsA(isA<FormatException>()));
    });

    test('maps an ISO-8601 deletion_requested_at to the matching DateTime', () {
      final dto = ProfileDto.fromJson(
        _fullRow(deletionRequestedAt: '2026-06-12T10:00:00Z'),
      );
      final profile = profileFromDto(dto);

      expect(profile.deletionRequestedAt, DateTime.utc(2026, 6, 12, 10));
    });

    test('a null or absent deletion_requested_at maps to null', () {
      // Explicit null.
      expect(
        profileFromDto(ProfileDto.fromJson(_fullRow())).deletionRequestedAt,
        isNull,
      );
      // Key absent entirely.
      final row = _fullRow()..remove('deletion_requested_at');
      expect(
        profileFromDto(ProfileDto.fromJson(row)).deletionRequestedAt,
        isNull,
      );
    });

    test('maps each theme_id wire token to the matching ProfileTheme', () {
      for (final entry in {
        'crimson': ProfileTheme.crimson,
        'ember': ProfileTheme.ember,
        'solar': ProfileTheme.solar,
        'chak': ProfileTheme.chak,
        'frost': ProfileTheme.frost,
        'abyss': ProfileTheme.abyss,
        'arcane': ProfileTheme.arcane,
        'rose': ProfileTheme.rose,
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

    test('a superseded theme_id token maps to the default theme', () {
      for (final token in ['classic', 'immersive', 'retro', 'analyst']) {
        final dto = ProfileDto.fromJson(_fullRow(themeId: token));
        expect(
          profileFromDto(dto).theme,
          ProfileTheme.crimson,
          reason: 'superseded theme_id "$token" should remap to the default',
        );
      }
    });

    test('maps an ISO-8601 created_at to the matching DateTime', () {
      final dto = ProfileDto.fromJson(
        _fullRow(createdAt: '2025-03-01T12:00:00Z'),
      );

      expect(profileFromDto(dto).createdAt, DateTime.utc(2025, 3, 1, 12));
    });

    test('an absent created_at maps to null', () {
      expect(profileFromDto(ProfileDto.fromJson(_fullRow())).createdAt, isNull);
    });

    test('an unknown theme_id falls back to the default theme', () {
      final dto = ProfileDto.fromJson(_fullRow(themeId: 'banana'));

      expect(profileFromDto(dto).theme, ProfileTheme.crimson);
    });

    test('profileEditToColumns builds the writable columns', () {
      const edit = ProfileEdit(
        displayName: 'Alice',
        bio: 'Hello',
        theme: ProfileTheme.frost,
        privacy: ProfilePrivacy.private,
        featuredPlatform: null,
      );
      final columns = profileEditToColumns(edit);

      expect(
        columns.keys,
        containsAll([
          'display_name',
          'bio',
          'theme_id',
          'privacy_level',
          'featured_platform',
        ]),
      );
      expect(columns['display_name'], 'Alice');
      expect(columns['bio'], 'Hello');
      expect(columns['theme_id'], 'frost');
      expect(columns['privacy_level'], 'private');

      // avatar_url is server-managed (set by the avatar-upload endpoint), so an
      // update must never write it; username and other server-managed columns
      // must also be absent.
      expect(columns.containsKey('avatar_url'), isFalse);
      expect(columns.containsKey('username'), isFalse);
      expect(columns.containsKey('id'), isFalse);
    });

    group('featured_platform wire mapping', () {
      test('a known wire token maps to the matching Platform', () {
        final dto = ProfileDto.fromJson(_fullRow(featuredPlatform: 'steam'));
        final profile = profileFromDto(dto);
        expect(profile.featuredPlatform, Platform.steam);
      });

      test('null wire token maps to null', () {
        final dto = ProfileDto.fromJson(_fullRow());
        final profile = profileFromDto(dto);
        expect(profile.featuredPlatform, isNull);
      });

      test('an unknown wire token maps to null (soft resolution)', () {
        final dto = ProfileDto.fromJson(
          _fullRow(featuredPlatform: 'unknown_platform_xyz'),
        );
        final profile = profileFromDto(dto);
        expect(profile.featuredPlatform, isNull);
      });

      test(
        'profileEditToColumns emits the wire token for a selected platform',
        () {
          const edit = ProfileEdit(
            displayName: 'Bob',
            bio: null,
            theme: ProfileTheme.crimson,
            privacy: ProfilePrivacy.public,
            featuredPlatform: Platform.steam,
          );
          final columns = profileEditToColumns(edit);
          expect(columns['featured_platform'], 'steam');
        },
      );

      test('profileEditToColumns emits null when platform is cleared', () {
        const edit = ProfileEdit(
          displayName: 'Bob',
          bio: null,
          theme: ProfileTheme.crimson,
          privacy: ProfilePrivacy.public,
          featuredPlatform: null,
        );
        final columns = profileEditToColumns(edit);
        expect(columns['featured_platform'], isNull);
      });
    });

    group('layout wire mapping', () {
      test('parses full and pair rows in order with their ids', () {
        final profile = profileFromDto(
          ProfileDto.fromJson(
            _fullRow(
              layout: [
                {
                  't': 'full',
                  'c': ['id-a'],
                },
                {
                  't': 'pair',
                  'c': ['id-b', 'id-c'],
                },
                {
                  't': 'pair',
                  'c': ['id-d', null],
                },
              ],
            ),
          ),
        );

        expect(profile.layout, [
          const FullRow('id-a'),
          const PairRow(left: 'id-b', right: 'id-c'),
          const PairRow(left: 'id-d'),
        ]);
      });

      test('an absent or empty layout maps to const []', () {
        expect(profileFromDto(ProfileDto.fromJson(_fullRow())).layout, isEmpty);
        expect(
          profileFromDto(ProfileDto.fromJson(_fullRow(layout: []))).layout,
          isEmpty,
        );
      });

      test('drops malformed rows and slots without throwing', () {
        // Every entry but the last is malformed in a distinct way; the parser
        // must drop each rather than throw or keep garbage.
        final profile = profileFromDto(
          ProfileDto.fromJson(
            _fullRow(
              layout: [
                'not-a-map',
                {'t': 'full'}, // missing c
                {'t': 'full', 'c': <dynamic>[]}, // empty c
                {
                  't': 'full',
                  'c': [42], // non-string id
                },
                {
                  't': 'full',
                  'c': [''], // empty-string id
                },
                {
                  't': 'pair',
                  'c': [null, null], // both-null pair
                },
                {
                  't': 'wat',
                  'c': ['x'], // unknown row type
                },
                {
                  't': 'full',
                  'c': ['keep-me'],
                },
              ],
            ),
          ),
        );

        expect(profile.layout, [const FullRow('keep-me')]);
      });
    });
  });
}
