import 'dart:io';

import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/observability/observability.dart';
import 'package:featgg/src/features/profile/data/profile_data_source.dart';
import 'package:featgg/src/features/profile/data/profile_dto.dart';
import 'package:featgg/src/features/profile/data/profile_repository_impl.dart';
import 'package:featgg/src/features/profile/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Hand-rolled recording reporter — mirrors _RecordingReporter in auth tests.
final class _RecordingReporter implements CrashReporter {
  final List<Object> reported = [];

  @override
  Future<void> reportError(Object error, StackTrace? stackTrace) async {
    reported.add(error);
  }
}

/// Callback-driven fake for the ProfileDataSource seam.
final class _FakeDataSource implements ProfileDataSource {
  _FakeDataSource({this.onFetch, this.onUpdate});

  final Future<ProfileDto?> Function(String userId)? onFetch;
  final Future<ProfileDto> Function(String userId, Map<String, dynamic> values)?
  onUpdate;
  int fetchCalls = 0;
  int updateCalls = 0;

  @override
  Future<ProfileDto?> fetchProfileRow(String userId) {
    fetchCalls++;
    return onFetch?.call(userId) ?? Future.value(null);
  }

  @override
  Future<ProfileDto> updateProfileRow(
    String userId,
    Map<String, dynamic> values,
  ) {
    updateCalls++;
    if (onUpdate != null) return onUpdate!(userId, values);
    throw UnimplementedError('onUpdate not set');
  }
}

final _validDto = ProfileDto.fromJson(const {
  'id': 'user-123',
  'username': 'testuser',
  'display_name': 'Test User',
  'avatar_url': 'https://example.com/avatar.png',
  'bio': 'Hello world',
  'theme_id': 'classic',
  'privacy_level': 'public',
  'featured_platform': null,
});

ProfileRepositoryImpl _repo(
  _FakeDataSource dataSource,
  _RecordingReporter reporter, {
  String? userId = 'user-123',
}) => ProfileRepositoryImpl(dataSource, () => userId, reporter);

void main() {
  group('ProfileRepositoryImpl.fetchMyProfile', () {
    test('returns Right(Profile) on a valid row', () async {
      final dataSource = _FakeDataSource(onFetch: (_) async => _validDto);
      final result = await _repo(
        dataSource,
        _RecordingReporter(),
      ).fetchMyProfile();

      expect(result.isRight(), isTrue);
      result.fold((_) => fail('expected Right'), (profile) {
        expect(profile.id, 'user-123');
        expect(profile.username, 'testuser');
        expect(profile.displayName, 'Test User');
        expect(profile.privacy, ProfilePrivacy.public);
      });
    });

    test(
      'null currentUser returns Left(AuthFailure) and is not reported',
      () async {
        final reporter = _RecordingReporter();
        final dataSource = _FakeDataSource();
        final result = await _repo(
          dataSource,
          reporter,
          userId: null,
        ).fetchMyProfile();

        result.fold(
          (f) => expect(f, isA<AuthFailure>()),
          (_) => fail('expected Left'),
        );
        expect(reporter.reported, isEmpty);
        expect(dataSource.fetchCalls, equals(0));
      },
    );

    test(
      'AuthException 401 returns Left(AuthFailure) and is not reported',
      () async {
        final reporter = _RecordingReporter();
        final dataSource = _FakeDataSource(
          onFetch: (_) async =>
              throw const AuthException('expired', statusCode: '401'),
        );
        final result = await _repo(dataSource, reporter).fetchMyProfile();

        result.fold(
          (f) => expect(f, isA<AuthFailure>()),
          (_) => fail('expected Left'),
        );
        expect(reporter.reported, isEmpty);
      },
    );

    test('PostgrestException 403 returns Left(AuthFailure)', () async {
      final reporter = _RecordingReporter();
      final dataSource = _FakeDataSource(
        onFetch: (_) async =>
            throw PostgrestException(message: 'denied', code: '403'),
      );
      final result = await _repo(dataSource, reporter).fetchMyProfile();

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
      expect(reporter.reported, isEmpty);
    });

    test('PostgrestException PGRST301 returns Left(AuthFailure)', () async {
      final reporter = _RecordingReporter();
      final dataSource = _FakeDataSource(
        onFetch: (_) async =>
            throw PostgrestException(message: 'jwt expired', code: 'PGRST301'),
      );
      final result = await _repo(dataSource, reporter).fetchMyProfile();

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
      expect(reporter.reported, isEmpty);
    });

    test('null DTO returns Left(UnexpectedFailure) and is reported', () async {
      final reporter = _RecordingReporter();
      final dataSource = _FakeDataSource(onFetch: (_) async => null);
      final result = await _repo(dataSource, reporter).fetchMyProfile();

      result.fold(
        (f) => expect(f, isA<UnexpectedFailure>()),
        (_) => fail('expected Left'),
      );
      expect(reporter.reported, hasLength(1));
    });

    test(
      'SocketException returns Left(NetworkFailure) and is not reported',
      () async {
        final reporter = _RecordingReporter();
        final dataSource = _FakeDataSource(
          onFetch: (_) async => throw const SocketException('no route to host'),
        );
        final result = await _repo(dataSource, reporter).fetchMyProfile();

        result.fold(
          (f) => expect(f, isA<NetworkFailure>()),
          (_) => fail('expected Left'),
        );
        expect(reporter.reported, isEmpty);
      },
    );

    test(
      'arbitrary error returns Left(UnexpectedFailure) and is reported',
      () async {
        final reporter = _RecordingReporter();
        final dataSource = _FakeDataSource(
          onFetch: (_) async => throw Exception('boom'),
        );
        final result = await _repo(dataSource, reporter).fetchMyProfile();

        result.fold(
          (f) => expect(f, isA<UnexpectedFailure>()),
          (_) => fail('expected Left'),
        );
        expect(reporter.reported, hasLength(1));
      },
    );

    test(
      'parse fault from the data source returns Left(UnexpectedFailure) and is reported',
      () async {
        final reporter = _RecordingReporter();
        final dataSource = _FakeDataSource(
          onFetch: (_) async => throw const FormatException('bad column'),
        );
        final result = await _repo(dataSource, reporter).fetchMyProfile();

        result.fold(
          (f) => expect(f, isA<UnexpectedFailure>()),
          (_) => fail('expected Left'),
        );
        expect(reporter.reported, hasLength(1));
      },
    );
  });

  group('ProfileRepositoryImpl.fetchPublicProfile', () {
    test('returns Right(Profile) on a valid row', () async {
      final dataSource = _FakeDataSource(onFetch: (_) async => _validDto);
      final result = await _repo(
        dataSource,
        _RecordingReporter(),
      ).fetchPublicProfile('user-123');

      expect(result.isRight(), isTrue);
      result.fold((_) => fail('expected Right'), (profile) {
        expect(profile, isNotNull);
        expect(profile!.id, 'user-123');
        expect(profile.username, 'testuser');
      });
    });

    test('returns Right(null) on a null row (private/not-found)', () async {
      final reporter = _RecordingReporter();
      final dataSource = _FakeDataSource(onFetch: (_) async => null);
      final result = await _repo(
        dataSource,
        reporter,
      ).fetchPublicProfile('user-999');

      result.fold(
        (f) => fail('expected Right(null), got Left'),
        (profile) => expect(profile, isNull),
      );
      expect(reporter.reported, isEmpty);
    });

    test(
      'SocketException returns Left(NetworkFailure) and is not reported',
      () async {
        final reporter = _RecordingReporter();
        final dataSource = _FakeDataSource(
          onFetch: (_) async => throw const SocketException('no route to host'),
        );
        final result = await _repo(
          dataSource,
          reporter,
        ).fetchPublicProfile('user-123');

        result.fold(
          (f) => expect(f, isA<NetworkFailure>()),
          (_) => fail('expected Left'),
        );
        expect(reporter.reported, isEmpty);
      },
    );
  });

  group('ProfileRepositoryImpl.updateMyProfile', () {
    // avatar_url is server-managed; it must not appear in the writable-column
    // map emitted by profileEditToColumns.
    test('profileEditToColumns does not emit avatar_url', () {
      const edit = ProfileEdit(
        displayName: 'Updated Name',
        bio: 'New bio',
        theme: ProfileTheme.retro,
        privacy: ProfilePrivacy.private,
        featuredPlatform: null,
      );
      final columns = profileEditToColumns(edit);
      expect(columns.containsKey('avatar_url'), isFalse);
    });

    const edit = ProfileEdit(
      displayName: 'Updated Name',
      bio: 'New bio',
      theme: ProfileTheme.retro,
      privacy: ProfilePrivacy.private,
      featuredPlatform: null,
    );

    final updatedDto = ProfileDto.fromJson(const {
      'id': 'user-123',
      'username': 'testuser',
      'display_name': 'Updated Name',
      'avatar_url': null,
      'bio': 'New bio',
      'theme_id': 'retro',
      'privacy_level': 'private',
      'featured_platform': null,
    });

    test('returns Right(Profile) on a valid row', () async {
      final dataSource = _FakeDataSource(onUpdate: (_, _) async => updatedDto);
      final result = await _repo(
        dataSource,
        _RecordingReporter(),
      ).updateMyProfile(edit);

      expect(result.isRight(), isTrue);
      result.fold((_) => fail('expected Right'), (profile) {
        expect(profile.displayName, 'Updated Name');
        expect(profile.theme, ProfileTheme.retro);
        expect(profile.privacy, ProfilePrivacy.private);
      });
    });

    test(
      'null currentUser returns Left(AuthFailure) and does not call the seam',
      () async {
        final reporter = _RecordingReporter();
        final dataSource = _FakeDataSource();
        final result = await _repo(
          dataSource,
          reporter,
          userId: null,
        ).updateMyProfile(edit);

        result.fold(
          (f) => expect(f, isA<AuthFailure>()),
          (_) => fail('expected Left'),
        );
        expect(reporter.reported, isEmpty);
        expect(dataSource.updateCalls, equals(0));
      },
    );

    test(
      'a constraint-violation PostgrestException returns Left(InputFailure) and is not reported',
      () async {
        final reporter = _RecordingReporter();
        final dataSource = _FakeDataSource(
          onUpdate: (_, _) async => throw PostgrestException(
            message: 'check violation',
            code: '23514',
          ),
        );
        final result = await _repo(dataSource, reporter).updateMyProfile(edit);

        result.fold(
          (f) => expect(f, isA<InputFailure>()),
          (_) => fail('expected Left'),
        );
        // InputFailure is expected control flow — must not be crash-reported.
        expect(reporter.reported, isEmpty);
      },
    );

    test(
      'a parse fault on update returns Left(UnexpectedFailure) and is reported',
      () async {
        final reporter = _RecordingReporter();
        final dataSource = _FakeDataSource(
          onUpdate: (_, _) async =>
              throw const FormatException('bad column on update'),
        );
        final result = await _repo(dataSource, reporter).updateMyProfile(edit);

        result.fold(
          (f) => expect(f, isA<UnexpectedFailure>()),
          (_) => fail('expected Left'),
        );
        expect(reporter.reported, hasLength(1));
      },
    );
  });
}
