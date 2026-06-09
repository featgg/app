import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/observability/observability.dart';
import 'package:featgg/src/features/profile/data/avatar_dto.dart';
import 'package:featgg/src/features/profile/data/avatar_repository_impl.dart';
import 'package:featgg/src/features/profile/data/avatar_upload_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Hand-rolled recording crash reporter.
final class _RecordingReporter implements CrashReporter {
  final List<Object> reported = [];

  @override
  Future<void> reportError(Object error, StackTrace? stackTrace) async {
    reported.add(error);
  }
}

/// Callback-driven fake for the AvatarUploadSource seam.
final class _FakeUploadSource implements AvatarUploadSource {
  _FakeUploadSource(this._onUpload);

  final Future<AvatarUploadDto> Function(Uint8List bytes, String contentType)
  _onUpload;

  @override
  Future<AvatarUploadDto> uploadAvatar(Uint8List bytes, String contentType) =>
      _onUpload(bytes, contentType);
}

AvatarRepositoryImpl _repo(
  AvatarUploadSource source,
  _RecordingReporter reporter,
) => AvatarRepositoryImpl(source, reporter);

/// Builds a [FunctionException] with the given status and optional code/message
/// in the details map.
FunctionException _fnEx(
  int status, {
  String? code,
  String? message,
  List<String>? categories,
  Object? retryAfter,
}) {
  final details = <String, dynamic>{};
  if (code != null) details['code'] = code;
  if (message != null) details['message'] = message;
  if (categories != null) details['categories'] = categories;
  if (retryAfter != null) details['retry_after'] = retryAfter;
  return FunctionException(
    status: status,
    details: details.isEmpty ? null : details,
    reasonPhrase: message,
  );
}

void main() {
  group('AvatarRepositoryImpl.uploadAvatar — success', () {
    test('returns Right(avatarUrl) on a valid success envelope', () async {
      const url = 'https://cdn.example.com/avatar.jpg';
      final source = _FakeUploadSource(
        (_, _) async => const AvatarUploadDto(avatarUrl: url),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
      ).uploadAvatar(bytes: Uint8List(1), contentType: 'image/jpeg');

      expect(result.isRight(), isTrue);
      result.fold((_) => fail('expected Right'), (u) => expect(u, url));
      expect(reporter.reported, isEmpty);
    });
  });

  group('AvatarRepositoryImpl.uploadAvatar — FunctionException mapping', () {
    test(
      'MODERATION_REJECTED / 422 → ModerationRejectedFailure with categories',
      () async {
        final source = _FakeUploadSource(
          (_, _) async => throw _fnEx(
            422,
            code: 'MODERATION_REJECTED',
            categories: ['nudity'],
          ),
        );
        final reporter = _RecordingReporter();
        final result = await _repo(
          source,
          reporter,
        ).uploadAvatar(bytes: Uint8List(1), contentType: 'image/jpeg');

        result.fold((f) {
          expect(f, isA<ModerationRejectedFailure>());
          expect((f as ModerationRejectedFailure).categories, ['nudity']);
          expect(f.isExpected, isTrue);
        }, (_) => fail('expected Left'));
        // Expected failure — must not be crash-reported.
        expect(reporter.reported, isEmpty);
      },
    );

    test('PAYLOAD_TOO_LARGE / 413 → InputFailure, not reported', () async {
      final source = _FakeUploadSource(
        (_, _) async => throw _fnEx(413, code: 'PAYLOAD_TOO_LARGE'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
      ).uploadAvatar(bytes: Uint8List(1), contentType: 'image/jpeg');

      result.fold(
        (f) => expect(f, isA<InputFailure>()),
        (_) => fail('expected Left'),
      );
      expect(reporter.reported, isEmpty);
    });

    test('UNSUPPORTED_MEDIA_TYPE / 415 → InputFailure, not reported', () async {
      final source = _FakeUploadSource(
        (_, _) async => throw _fnEx(415, code: 'UNSUPPORTED_MEDIA_TYPE'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
      ).uploadAvatar(bytes: Uint8List(1), contentType: 'image/jpeg');

      result.fold(
        (f) => expect(f, isA<InputFailure>()),
        (_) => fail('expected Left'),
      );
      expect(reporter.reported, isEmpty);
    });

    test('UNAUTHORIZED / 401 → AuthFailure, not reported', () async {
      final source = _FakeUploadSource(
        (_, _) async => throw _fnEx(401, code: 'UNAUTHORIZED'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
      ).uploadAvatar(bytes: Uint8List(1), contentType: 'image/jpeg');

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
      expect(reporter.reported, isEmpty);
    });

    test(
      'MODERATION_UNAVAILABLE / 500 → ModerationUnavailableFailure, reported',
      () async {
        final source = _FakeUploadSource(
          (_, _) async => throw _fnEx(500, code: 'MODERATION_UNAVAILABLE'),
        );
        final reporter = _RecordingReporter();
        final result = await _repo(
          source,
          reporter,
        ).uploadAvatar(bytes: Uint8List(1), contentType: 'image/jpeg');

        result.fold(
          (f) => expect(f, isA<ModerationUnavailableFailure>()),
          (_) => fail('expected Left'),
        );
        expect(reporter.reported, hasLength(1));
      },
    );

    test('unknown code → UnexpectedFailure, reported', () async {
      final source = _FakeUploadSource(
        (_, _) async => throw _fnEx(418, code: 'IM_A_TEAPOT'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
      ).uploadAvatar(bytes: Uint8List(1), contentType: 'image/jpeg');

      result.fold(
        (f) => expect(f, isA<UnexpectedFailure>()),
        (_) => fail('expected Left'),
      );
      expect(reporter.reported, hasLength(1));
    });

    test('AVATAR_COOLDOWN / 429 → RateLimitFailure, not reported', () async {
      final source = _FakeUploadSource(
        (_, _) async => throw _fnEx(429, code: 'AVATAR_COOLDOWN'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
      ).uploadAvatar(bytes: Uint8List(1), contentType: 'image/jpeg');

      result.fold((f) {
        expect(f, isA<RateLimitFailure>());
        expect(f.isExpected, isTrue);
      }, (_) => fail('expected Left'));
      expect(reporter.reported, isEmpty);
    });

    test(
      "AVATAR_COOLDOWN / 429 with details['retry_after']=5 → retryAfterSeconds == 5",
      () async {
        final source = _FakeUploadSource(
          (_, _) async =>
              throw _fnEx(429, code: 'AVATAR_COOLDOWN', retryAfter: 5),
        );
        final reporter = _RecordingReporter();
        final result = await _repo(
          source,
          reporter,
        ).uploadAvatar(bytes: Uint8List(1), contentType: 'image/jpeg');

        result.fold((f) {
          expect(f, isA<RateLimitFailure>());
          expect((f as RateLimitFailure).retryAfterSeconds, 5);
        }, (_) => fail('expected Left'));
        expect(reporter.reported, isEmpty);
      },
    );

    test(
      "AVATAR_COOLDOWN / 429 without retry_after → retryAfterSeconds == null",
      () async {
        final source = _FakeUploadSource(
          (_, _) async => throw _fnEx(429, code: 'AVATAR_COOLDOWN'),
        );
        final reporter = _RecordingReporter();
        final result = await _repo(
          source,
          reporter,
        ).uploadAvatar(bytes: Uint8List(1), contentType: 'image/jpeg');

        result.fold((f) {
          expect(f, isA<RateLimitFailure>());
          expect((f as RateLimitFailure).retryAfterSeconds, isNull);
        }, (_) => fail('expected Left'));
        expect(reporter.reported, isEmpty);
      },
    );

    test(
      "AVATAR_COOLDOWN / 429 with malformed retry_after (non-int) → retryAfterSeconds == null",
      () async {
        final source = _FakeUploadSource(
          (_, _) async => throw _fnEx(
            429,
            code: 'AVATAR_COOLDOWN',
            retryAfter: 'not-a-number',
          ),
        );
        final reporter = _RecordingReporter();
        final result = await _repo(
          source,
          reporter,
        ).uploadAvatar(bytes: Uint8List(1), contentType: 'image/jpeg');

        result.fold((f) {
          expect(f, isA<RateLimitFailure>());
          expect((f as RateLimitFailure).retryAfterSeconds, isNull);
        }, (_) => fail('expected Left'));
        expect(reporter.reported, isEmpty);
      },
    );

    test(
      '429 detected by status alone (no code) → RateLimitFailure, not reported',
      () async {
        // No code in details — only HTTP status 429 triggers the branch.
        final source = _FakeUploadSource(
          (_, _) async => throw FunctionException(
            status: 429,
            details: null,
            reasonPhrase: null,
          ),
        );
        final reporter = _RecordingReporter();
        final result = await _repo(
          source,
          reporter,
        ).uploadAvatar(bytes: Uint8List(1), contentType: 'image/jpeg');

        result.fold(
          (f) => expect(f, isA<RateLimitFailure>()),
          (_) => fail('expected Left'),
        );
        expect(reporter.reported, isEmpty);
      },
    );
  });

  group(
    'AvatarRepositoryImpl.uploadAvatar — non-FunctionException mapping',
    () {
      test('SocketException → NetworkFailure, not reported', () async {
        final source = _FakeUploadSource(
          (_, _) async => throw const SocketException('no route to host'),
        );
        final reporter = _RecordingReporter();
        final result = await _repo(
          source,
          reporter,
        ).uploadAvatar(bytes: Uint8List(1), contentType: 'image/jpeg');

        result.fold(
          (f) => expect(f, isA<NetworkFailure>()),
          (_) => fail('expected Left'),
        );
        expect(reporter.reported, isEmpty);
      });

      test('TimeoutException → NetworkFailure, not reported', () async {
        final source = _FakeUploadSource(
          (_, _) async => throw TimeoutException('upload timed out'),
        );
        final reporter = _RecordingReporter();
        final result = await _repo(
          source,
          reporter,
        ).uploadAvatar(bytes: Uint8List(1), contentType: 'image/jpeg');

        result.fold(
          (f) => expect(f, isA<NetworkFailure>()),
          (_) => fail('expected Left'),
        );
        expect(reporter.reported, isEmpty);
      });

      test(
        'parse fault on the success body → UnexpectedFailure, reported',
        () async {
          final source = _FakeUploadSource(
            (_, _) async => throw const FormatException('bad json'),
          );
          final reporter = _RecordingReporter();
          final result = await _repo(
            source,
            reporter,
          ).uploadAvatar(bytes: Uint8List(1), contentType: 'image/jpeg');

          result.fold(
            (f) => expect(f, isA<UnexpectedFailure>()),
            (_) => fail('expected Left'),
          );
          expect(reporter.reported, hasLength(1));
        },
      );
    },
  );
}
