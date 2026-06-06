import 'dart:async';
import 'dart:io';

import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/observability/observability.dart';
import 'package:featgg/src/features/connections/data/connection_dto.dart';
import 'package:featgg/src/features/connections/data/connections_data_source.dart';
import 'package:featgg/src/features/connections/data/connections_repository_impl.dart';
import 'package:featgg/src/features/connections/data/link_account_dto.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

final class _RecordingReporter implements CrashReporter {
  final List<Object> reported = [];

  @override
  Future<void> reportError(Object error, StackTrace? stackTrace) async {
    reported.add(error);
  }
}

typedef _LinkFn = Future<LinkSuccessDto> Function(Map<String, dynamic> body);
typedef _UnlinkFn = Future<LinkSuccessDto> Function(String wireValue);
typedef _SyncFn = Future<SyncResultDto> Function(String functionName);
typedef _FetchFn = Future<List<ConnectionDto>> Function(String userId);

final class _FakeConnectionsDataSource implements ConnectionsDataSource {
  _FakeConnectionsDataSource({
    _LinkFn? onLink,
    _UnlinkFn? onUnlink,
    _SyncFn? onSync,
    _FetchFn? onFetch,
  }) : _onLink = onLink ?? ((_) async => const LinkSuccessDto(success: true)),
       _onUnlink =
           onUnlink ?? ((_) async => const LinkSuccessDto(success: true)),
       _onSync = onSync ?? ((_) async => const SyncResultDto(skipped: false)),
       _onFetch = onFetch ?? ((_) async => []);

  final _LinkFn _onLink;
  final _UnlinkFn _onUnlink;
  final _SyncFn _onSync;
  final _FetchFn _onFetch;

  @override
  Future<LinkSuccessDto> linkAccount(Map<String, dynamic> body) =>
      _onLink(body);

  @override
  Future<LinkSuccessDto> unlinkAccount(String wireValue) =>
      _onUnlink(wireValue);

  @override
  Future<SyncResultDto> syncPlatform(String functionName) =>
      _onSync(functionName);

  @override
  Future<List<ConnectionDto>> fetchConnections(String userId) =>
      _onFetch(userId);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

FunctionException _fnEx(int status, {String? code, String? message}) {
  final details = <String, dynamic>{};
  if (code != null) details['code'] = code;
  if (message != null) details['message'] = message;
  return FunctionException(
    status: status,
    details: details.isEmpty ? null : details,
    reasonPhrase: message,
  );
}

ConnectionsRepositoryImpl _repo(
  ConnectionsDataSource source,
  _RecordingReporter reporter, {
  String? userId = 'user-1',
}) => ConnectionsRepositoryImpl(source, () => userId, reporter);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ConnectionsRepositoryImpl.link', () {
    test('builds the steam wire body from form input and succeeds', () async {
      Map<String, dynamic>? capturedBody;
      final source = _FakeConnectionsDataSource(
        onLink: (body) async {
          capturedBody = body;
          return const LinkSuccessDto(success: true);
        },
      );
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
      ).link(platform: Platform.steam, formInput: {'remote_id': '12345'});

      expect(result.isRight(), isTrue);
      // The data layer owns the Shape-1 wire body; presentation passes only raw
      // form input. The platform token comes from the descriptor's wireValue.
      expect(capturedBody, {'platform': 'steam', 'remote_id': '12345'});
      expect(reporter.reported, isEmpty);
    });

    test('ALREADY_LINKED → Right(unit), not reported', () async {
      final source = _FakeConnectionsDataSource(
        onLink: (_) async => throw _fnEx(409, code: 'ALREADY_LINKED'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
      ).link(platform: Platform.steam, formInput: {'remote_id': '12345'});

      expect(result.isRight(), isTrue);
      expect(reporter.reported, isEmpty);
    });

    test('INVALID_REQUEST / 400 → Left(InputFailure), not reported', () async {
      final source = _FakeConnectionsDataSource(
        onLink: (_) async => throw _fnEx(400, code: 'INVALID_REQUEST'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
      ).link(platform: Platform.steam, formInput: {'remote_id': ''});

      result.fold(
        (f) => expect(f, isA<InputFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, isEmpty);
    });

    test('UNAUTHORIZED / 401 → Left(AuthFailure), not reported', () async {
      final source = _FakeConnectionsDataSource(
        onLink: (_) async => throw _fnEx(401, code: 'UNAUTHORIZED'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
      ).link(platform: Platform.steam, formInput: {'remote_id': '12345'});

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, isEmpty);
    });

    test('UPSTREAM_NOT_FOUND → Left(UpstreamFailure), not reported', () async {
      final source = _FakeConnectionsDataSource(
        onLink: (_) async => throw _fnEx(404, code: 'UPSTREAM_NOT_FOUND'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
      ).link(platform: Platform.steam, formInput: {'remote_id': '12345'});

      result.fold(
        (f) => expect(f, isA<UpstreamFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, isEmpty);
    });

    test('UPSTREAM_RATE_LIMIT → Left(UpstreamFailure), not reported', () async {
      final source = _FakeConnectionsDataSource(
        onLink: (_) async => throw _fnEx(429, code: 'UPSTREAM_RATE_LIMIT'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
      ).link(platform: Platform.steam, formInput: {'remote_id': '12345'});

      result.fold(
        (f) => expect(f, isA<UpstreamFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, isEmpty);
    });

    test('UPSTREAM_FAILURE → Left(UpstreamFailure), not reported', () async {
      final source = _FakeConnectionsDataSource(
        onLink: (_) async => throw _fnEx(502, code: 'UPSTREAM_FAILURE'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
      ).link(platform: Platform.steam, formInput: {'remote_id': '12345'});

      result.fold(
        (f) => expect(f, isA<UpstreamFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, isEmpty);
    });

    test('LINK_WRITE_FAILED / 500 → Left(ServerFailure), reported', () async {
      final source = _FakeConnectionsDataSource(
        onLink: (_) async => throw _fnEx(500, code: 'LINK_WRITE_FAILED'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
      ).link(platform: Platform.steam, formInput: {'remote_id': '12345'});

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, hasLength(1));
    });

    test('INTERNAL_ERROR / 500 → Left(ServerFailure), reported', () async {
      final source = _FakeConnectionsDataSource(
        onLink: (_) async => throw _fnEx(500, code: 'INTERNAL_ERROR'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
      ).link(platform: Platform.steam, formInput: {'remote_id': '12345'});

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, hasLength(1));
    });

    test('unknown code → Left(UnexpectedFailure), reported', () async {
      final source = _FakeConnectionsDataSource(
        onLink: (_) async => throw _fnEx(418, code: 'IM_A_TEAPOT'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
      ).link(platform: Platform.steam, formInput: {'remote_id': '12345'});

      result.fold(
        (f) => expect(f, isA<UnexpectedFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, hasLength(1));
    });

    test(
      'PAYLOAD_TOO_LARGE / 413 → Left(InputFailure), not reported',
      () async {
        final source = _FakeConnectionsDataSource(
          onLink: (_) async => throw _fnEx(413, code: 'PAYLOAD_TOO_LARGE'),
        );
        final reporter = _RecordingReporter();
        final result = await _repo(
          source,
          reporter,
        ).link(platform: Platform.steam, formInput: {'remote_id': '12345'});

        result.fold(
          (f) => expect(f, isA<InputFailure>()),
          (_) => fail('want Left'),
        );
        expect(reporter.reported, isEmpty);
      },
    );

    test(
      'UNSUPPORTED_MEDIA_TYPE / 415 → Left(InputFailure), not reported',
      () async {
        final source = _FakeConnectionsDataSource(
          onLink: (_) async => throw _fnEx(415, code: 'UNSUPPORTED_MEDIA_TYPE'),
        );
        final reporter = _RecordingReporter();
        final result = await _repo(
          source,
          reporter,
        ).link(platform: Platform.steam, formInput: {'remote_id': '12345'});

        result.fold(
          (f) => expect(f, isA<InputFailure>()),
          (_) => fail('want Left'),
        );
        expect(reporter.reported, isEmpty);
      },
    );

    test('SocketException → Left(NetworkFailure), not reported', () async {
      final source = _FakeConnectionsDataSource(
        onLink: (_) async => throw const SocketException('no route'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
      ).link(platform: Platform.steam, formInput: {'remote_id': '12345'});

      result.fold(
        (f) => expect(f, isA<NetworkFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, isEmpty);
    });

    test('TimeoutException → Left(NetworkFailure), not reported', () async {
      final source = _FakeConnectionsDataSource(
        onLink: (_) async => throw TimeoutException('timed out'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
      ).link(platform: Platform.steam, formInput: {'remote_id': '12345'});

      result.fold(
        (f) => expect(f, isA<NetworkFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, isEmpty);
    });
  });

  group('ConnectionsRepositoryImpl.unlink', () {
    test('returns Right(unit) on success', () async {
      final source = _FakeConnectionsDataSource();
      final reporter = _RecordingReporter();
      final result = await _repo(source, reporter).unlink(Platform.steam);

      expect(result.isRight(), isTrue);
    });

    test('UNLINK_FAILED / 500 → Left(ServerFailure), reported', () async {
      final source = _FakeConnectionsDataSource(
        onUnlink: (_) async => throw _fnEx(500, code: 'UNLINK_FAILED'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(source, reporter).unlink(Platform.steam);

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, hasLength(1));
    });
  });

  group('ConnectionsRepositoryImpl.refresh', () {
    test('returns Right(SyncResult) on success', () async {
      final source = _FakeConnectionsDataSource(
        onSync: (_) async => const SyncResultDto(skipped: false),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(source, reporter).refresh(Platform.steam);

      result.fold(
        (f) => fail('want Right, got $f'),
        (r) => expect(r.skipped, isFalse),
      );
    });

    test('skipped: true → Right(SyncResult{skipped: true})', () async {
      final source = _FakeConnectionsDataSource(
        onSync: (_) async => const SyncResultDto(skipped: true),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(source, reporter).refresh(Platform.steam);

      result.fold(
        (f) => fail('want Right, got $f'),
        (r) => expect(r.skipped, isTrue),
      );
    });

    test('SYNC_COOLDOWN → Left(SyncCooldownFailure), not reported', () async {
      final source = _FakeConnectionsDataSource(
        onSync: (_) async => throw _fnEx(429, code: 'SYNC_COOLDOWN'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(source, reporter).refresh(Platform.steam);

      result.fold(
        (f) => expect(f, isA<SyncCooldownFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, isEmpty);
    });

    test(
      'LINKED_ACCOUNT_NOT_FOUND → Left(UpstreamFailure), not reported',
      () async {
        final source = _FakeConnectionsDataSource(
          onSync: (_) async =>
              throw _fnEx(404, code: 'LINKED_ACCOUNT_NOT_FOUND'),
        );
        final reporter = _RecordingReporter();
        final result = await _repo(source, reporter).refresh(Platform.steam);

        result.fold(
          (f) => expect(f, isA<UpstreamFailure>()),
          (_) => fail('want Left'),
        );
        expect(reporter.reported, isEmpty);
      },
    );

    test(
      'MISSING_STORED_CREDENTIAL → Left(UpstreamFailure), not reported',
      () async {
        final source = _FakeConnectionsDataSource(
          onSync: (_) async =>
              throw _fnEx(404, code: 'MISSING_STORED_CREDENTIAL'),
        );
        final reporter = _RecordingReporter();
        final result = await _repo(source, reporter).refresh(Platform.steam);

        result.fold(
          (f) => expect(f, isA<UpstreamFailure>()),
          (_) => fail('want Left'),
        );
        expect(reporter.reported, isEmpty);
      },
    );

    test(
      'INVALID_STORED_ROUTING → Left(UpstreamFailure), not reported',
      () async {
        final source = _FakeConnectionsDataSource(
          onSync: (_) async => throw _fnEx(500, code: 'INVALID_STORED_ROUTING'),
        );
        final reporter = _RecordingReporter();
        final result = await _repo(source, reporter).refresh(Platform.steam);

        result.fold(
          (f) => expect(f, isA<UpstreamFailure>()),
          (_) => fail('want Left'),
        );
        expect(reporter.reported, isEmpty);
      },
    );

    test('SYNC_COMMIT_FAILED → Left(ServerFailure), reported', () async {
      final source = _FakeConnectionsDataSource(
        onSync: (_) async => throw _fnEx(500, code: 'SYNC_COMMIT_FAILED'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(source, reporter).refresh(Platform.steam);

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, hasLength(1));
    });

    test('COOLDOWN_CHECK_FAILED → Left(ServerFailure), reported', () async {
      final source = _FakeConnectionsDataSource(
        onSync: (_) async => throw _fnEx(500, code: 'COOLDOWN_CHECK_FAILED'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(source, reporter).refresh(Platform.steam);

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, hasLength(1));
    });

    test(
      'status >= 500 with no code → Left(ServerFailure), reported',
      () async {
        final source = _FakeConnectionsDataSource(
          onSync: (_) async => throw FunctionException(
            status: 503,
            details: null,
            reasonPhrase: null,
          ),
        );
        final reporter = _RecordingReporter();
        final result = await _repo(source, reporter).refresh(Platform.steam);

        result.fold(
          (f) => expect(f, isA<ServerFailure>()),
          (_) => fail('want Left'),
        );
        expect(reporter.reported, hasLength(1));
      },
    );
  });

  group('ConnectionsRepositoryImpl.fetchMyConnections', () {
    test('returns Left(AuthFailure) when no user session', () async {
      final source = _FakeConnectionsDataSource();
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
        userId: null,
      ).fetchMyConnections();

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, isEmpty);
    });

    test('maps a linked_accounts row to Connection list', () async {
      final source = _FakeConnectionsDataSource(
        onFetch: (_) async => [
          ConnectionDto.fromJson({
            'platform': 'steam',
            'status': 'active',
            'created_at': '2026-01-01T00:00:00Z',
            'last_sync_at': '2026-06-01T12:00:00Z',
            'remote_id': '12345',
          }),
        ],
      );
      final reporter = _RecordingReporter();
      final result = await _repo(source, reporter).fetchMyConnections();

      result.fold((f) => fail('want Right, got $f'), (list) {
        expect(list, hasLength(1));
        expect(list[0].platform, Platform.steam);
        expect(list[0].status, ConnectionStatus.active);
        expect(list[0].remoteId, '12345');
      });
    });

    test(
      'parse fault on unknown status → Left(UnexpectedFailure), reported',
      () async {
        final source = _FakeConnectionsDataSource(
          onFetch: (_) async => [
            ConnectionDto.fromJson({
              'platform': 'steam',
              'status': 'unknown_status',
              'created_at': '2026-01-01T00:00:00Z',
            }),
          ],
        );
        final reporter = _RecordingReporter();
        final result = await _repo(source, reporter).fetchMyConnections();

        result.fold(
          (f) => expect(f, isA<UnexpectedFailure>()),
          (_) => fail('want Left'),
        );
        expect(reporter.reported, hasLength(1));
      },
    );
  });

  group('Crash-report gate', () {
    test('ALREADY_LINKED is not crash-reported', () async {
      final reporter = _RecordingReporter();
      await _repo(
        _FakeConnectionsDataSource(
          onLink: (_) async => throw _fnEx(409, code: 'ALREADY_LINKED'),
        ),
        reporter,
      ).link(platform: Platform.steam, formInput: {'remote_id': '12345'});
      expect(reporter.reported, isEmpty);
    });

    test('SYNC_COOLDOWN is not crash-reported', () async {
      final reporter = _RecordingReporter();
      await _repo(
        _FakeConnectionsDataSource(
          onSync: (_) async => throw _fnEx(429, code: 'SYNC_COOLDOWN'),
        ),
        reporter,
      ).refresh(Platform.steam);
      expect(reporter.reported, isEmpty);
    });

    test('UPSTREAM_NOT_FOUND is not crash-reported', () async {
      final reporter = _RecordingReporter();
      await _repo(
        _FakeConnectionsDataSource(
          onLink: (_) async => throw _fnEx(404, code: 'UPSTREAM_NOT_FOUND'),
        ),
        reporter,
      ).link(platform: Platform.steam, formInput: {'remote_id': '12345'});
      expect(reporter.reported, isEmpty);
    });

    test('ServerFailure (INTERNAL_ERROR) is crash-reported', () async {
      final reporter = _RecordingReporter();
      await _repo(
        _FakeConnectionsDataSource(
          onLink: (_) async => throw _fnEx(500, code: 'INTERNAL_ERROR'),
        ),
        reporter,
      ).link(platform: Platform.steam, formInput: {'remote_id': '12345'});
      expect(reporter.reported, hasLength(1));
    });

    test('UnexpectedFailure (unknown code) is crash-reported', () async {
      final reporter = _RecordingReporter();
      await _repo(
        _FakeConnectionsDataSource(
          onLink: (_) async => throw _fnEx(418, code: 'IM_A_TEAPOT'),
        ),
        reporter,
      ).link(platform: Platform.steam, formInput: {'remote_id': '12345'});
      expect(reporter.reported, hasLength(1));
    });
  });
}
