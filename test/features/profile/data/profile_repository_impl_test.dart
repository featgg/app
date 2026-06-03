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
  _FakeDataSource({this.onFetch});

  final Future<ProfileDto?> Function(String userId)? onFetch;
  int calls = 0;

  @override
  Future<ProfileDto?> fetchProfileRow(String userId) {
    calls++;
    return onFetch?.call(userId) ?? Future.value(null);
  }
}

final _validDto = ProfileDto.fromJson(const {
  'id': 'user-123',
  'username': 'testuser',
  'display_name': 'Test User',
  'avatar_url': 'https://example.com/avatar.png',
  'bio': 'Hello world',
  'privacy_level': 'public',
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
        expect(dataSource.calls, equals(0));
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
}
