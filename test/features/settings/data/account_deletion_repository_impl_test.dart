import 'dart:async';
import 'dart:io';

import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/observability/observability.dart';
import 'package:featgg/src/features/settings/data/account_deletion_data_source.dart';
import 'package:featgg/src/features/settings/data/account_deletion_dto.dart';
import 'package:featgg/src/features/settings/data/account_deletion_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class _RecordingReporter implements CrashReporter {
  final List<Object> reported = [];

  @override
  Future<void> reportError(Object error, StackTrace? stackTrace) async {
    reported.add(error);
  }
}

typedef _RequestFn = Future<DeletionRequestDto> Function();
typedef _ConfirmFn = Future<DeletionConfirmDto> Function(String code);
typedef _CancelFn = Future<DeletionCancelDto> Function();
typedef _StatusFn = Future<DeletionStatusDto> Function();

final class _FakeDataSource implements AccountDeletionDataSource {
  _FakeDataSource({
    _RequestFn? onRequest,
    _ConfirmFn? onConfirm,
    _CancelFn? onCancel,
    _StatusFn? onStatus,
  }) : _onRequest =
           onRequest ??
           (() async => const DeletionRequestDto(success: true, otpSent: true)),
       _onConfirm =
           onConfirm ??
           ((_) async => const DeletionConfirmDto(
             success: true,
             deletionScheduledAt: '2026-06-18T00:00:00Z',
           )),
       _onCancel =
           onCancel ??
           (() async =>
               const DeletionCancelDto(success: true, cancelled: true)),
       _onStatus =
           onStatus ?? (() async => const DeletionStatusDto(requestedAt: null));

  final _RequestFn _onRequest;
  final _ConfirmFn _onConfirm;
  final _CancelFn _onCancel;
  final _StatusFn _onStatus;

  @override
  Future<DeletionRequestDto> requestDeletion() => _onRequest();

  @override
  Future<DeletionConfirmDto> confirmDeletion(String code) => _onConfirm(code);

  @override
  Future<DeletionCancelDto> cancelDeletion() => _onCancel();

  @override
  Future<DeletionStatusDto> fetchDeletionStatus() => _onStatus();
}

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

({AccountDeletionRepositoryImpl repo, _RecordingReporter reporter}) _subject(
  _FakeDataSource source,
) {
  final reporter = _RecordingReporter();
  return (
    repo: AccountDeletionRepositoryImpl(source, reporter),
    reporter: reporter,
  );
}

void main() {
  group('AccountDeletionRepositoryImpl', () {
    test('requestDeletion success → Right(unit)', () async {
      final s = _subject(_FakeDataSource());
      final result = await s.repo.requestDeletion();
      expect(result.isRight(), isTrue);
    });

    test('confirmDeletion success → Right(DeletionSchedule) with parsed UTC '
        'date', () async {
      final s = _subject(_FakeDataSource());
      final result = await s.repo.confirmDeletion('123456');
      final schedule = result.fold((_) => null, (r) => r);
      expect(schedule, isNotNull);
      expect(schedule!.scheduledAt, DateTime.utc(2026, 6, 18));
      expect(schedule.scheduledAt.isUtc, isTrue);
    });

    test('cancelDeletion success → Right(unit)', () async {
      final s = _subject(_FakeDataSource());
      final result = await s.repo.cancelDeletion();
      expect(result.isRight(), isTrue);
    });

    test('confirm INVALID_OTP (401) → InputFailure, not AuthFailure, not '
        'crash-reported', () async {
      final s = _subject(
        _FakeDataSource(
          onConfirm: (_) async => throw _fnEx(401, code: 'INVALID_OTP'),
        ),
      );
      final failure = (await s.repo.confirmDeletion(
        '000000',
      )).fold((f) => f, (_) => null);
      expect(failure, isA<InputFailure>());
      expect(s.reporter.reported, isEmpty);
    });

    test('UNAUTHORIZED (401) → AuthFailure, not crash-reported', () async {
      final s = _subject(
        _FakeDataSource(
          onConfirm: (_) async => throw _fnEx(401, code: 'UNAUTHORIZED'),
        ),
      );
      final failure = (await s.repo.confirmDeletion(
        '123456',
      )).fold((f) => f, (_) => null);
      expect(failure, isA<AuthFailure>());
      expect(s.reporter.reported, isEmpty);
    });

    test('INVALID_REQUEST (400) → InputFailure', () async {
      final s = _subject(
        _FakeDataSource(
          onConfirm: (_) async => throw _fnEx(400, code: 'INVALID_REQUEST'),
        ),
      );
      final failure = (await s.repo.confirmDeletion(
        '1',
      )).fold((f) => f, (_) => null);
      expect(failure, isA<InputFailure>());
    });

    test(
      'ACCOUNT_DELETE_FAILED (500) → ServerFailure and crash-reported',
      () async {
        final s = _subject(
          _FakeDataSource(
            onRequest: () async =>
                throw _fnEx(500, code: 'ACCOUNT_DELETE_FAILED'),
          ),
        );
        final failure = (await s.repo.requestDeletion()).fold(
          (f) => f,
          (_) => null,
        );
        expect(failure, isA<ServerFailure>());
        expect(s.reporter.reported, isNotEmpty);
      },
    );

    test('INTERNAL_ERROR (500) → ServerFailure', () async {
      final s = _subject(
        _FakeDataSource(
          onRequest: () async => throw _fnEx(500, code: 'INTERNAL_ERROR'),
        ),
      );
      final failure = (await s.repo.requestDeletion()).fold(
        (f) => f,
        (_) => null,
      );
      expect(failure, isA<ServerFailure>());
    });

    test('OTP_RATE_LIMIT (429) → AuthRateLimitFailure, not '
        'crash-reported', () async {
      final s = _subject(
        _FakeDataSource(
          onRequest: () async => throw _fnEx(429, code: 'OTP_RATE_LIMIT'),
        ),
      );
      final failure = (await s.repo.requestDeletion()).fold(
        (f) => f,
        (_) => null,
      );
      expect(failure, isA<AuthRateLimitFailure>());
      expect(s.reporter.reported, isEmpty);
    });

    test('malformed deletion_scheduled_at → UnexpectedFailure and '
        'crash-reported', () async {
      final s = _subject(
        _FakeDataSource(
          onConfirm: (_) async => const DeletionConfirmDto(
            success: true,
            deletionScheduledAt: 'not-a-date',
          ),
        ),
      );
      final failure = (await s.repo.confirmDeletion(
        '123456',
      )).fold((f) => f, (_) => null);
      expect(failure, isA<UnexpectedFailure>());
      expect(s.reporter.reported, isNotEmpty);
    });

    test('SocketException → NetworkFailure, not crash-reported', () async {
      final s = _subject(
        _FakeDataSource(
          onRequest: () async => throw const SocketException('down'),
        ),
      );
      final failure = (await s.repo.requestDeletion()).fold(
        (f) => f,
        (_) => null,
      );
      expect(failure, isA<NetworkFailure>());
      expect(s.reporter.reported, isEmpty);
    });

    test('TimeoutException → NetworkFailure', () async {
      final s = _subject(
        _FakeDataSource(onRequest: () async => throw TimeoutException('slow')),
      );
      final failure = (await s.repo.requestDeletion()).fold(
        (f) => f,
        (_) => null,
      );
      expect(failure, isA<NetworkFailure>());
    });
  });

  group('AccountDeletionRepositoryImpl.fetchDeletionStatus', () {
    test('a timestamp payload → pending status 7 days out, in UTC', () async {
      final s = _subject(
        _FakeDataSource(
          onStatus: () async =>
              const DeletionStatusDto(requestedAt: '2026-06-12T10:00:00Z'),
        ),
      );
      final status = (await s.repo.fetchDeletionStatus()).fold(
        (_) => null,
        (r) => r,
      );
      expect(status, isNotNull);
      expect(status!.isPending, isTrue);
      expect(status.requestedAt, DateTime.utc(2026, 6, 12, 10));
      expect(status.requestedAt!.isUtc, isTrue);
      expect(status.scheduledAt, DateTime.utc(2026, 6, 19, 10));
    });

    test(
      'a null payload → non-pending status with no scheduled target',
      () async {
        final s = _subject(_FakeDataSource());
        final status = (await s.repo.fetchDeletionStatus()).fold(
          (_) => null,
          (r) => r,
        );
        expect(status, isNotNull);
        expect(status!.isPending, isFalse);
        expect(status.scheduledAt, isNull);
      },
    );

    test('PostgrestException 401 → AuthFailure, not crash-reported', () async {
      final s = _subject(
        _FakeDataSource(
          onStatus: () async =>
              throw PostgrestException(message: 'no session', code: '401'),
        ),
      );
      final failure = (await s.repo.fetchDeletionStatus()).fold(
        (f) => f,
        (_) => null,
      );
      expect(failure, isA<AuthFailure>());
      expect(s.reporter.reported, isEmpty);
    });

    test('PostgrestException PGRST301 → AuthFailure', () async {
      final s = _subject(
        _FakeDataSource(
          onStatus: () async => throw PostgrestException(
            message: 'jwt expired',
            code: 'PGRST301',
          ),
        ),
      );
      final failure = (await s.repo.fetchDeletionStatus()).fold(
        (f) => f,
        (_) => null,
      );
      expect(failure, isA<AuthFailure>());
    });

    test('a parse fault → UnexpectedFailure and crash-reported', () async {
      final s = _subject(
        _FakeDataSource(
          onStatus: () async =>
              const DeletionStatusDto(requestedAt: 'not-a-date'),
        ),
      );
      final failure = (await s.repo.fetchDeletionStatus()).fold(
        (f) => f,
        (_) => null,
      );
      expect(failure, isA<UnexpectedFailure>());
      expect(s.reporter.reported, isNotEmpty);
    });

    test('SocketException → NetworkFailure, not crash-reported', () async {
      // The transport branch must survive the PostgrestException branch being
      // inserted ahead of it.
      final s = _subject(
        _FakeDataSource(
          onStatus: () async => throw const SocketException('down'),
        ),
      );
      final failure = (await s.repo.fetchDeletionStatus()).fold(
        (f) => f,
        (_) => null,
      );
      expect(failure, isA<NetworkFailure>());
      expect(s.reporter.reported, isEmpty);
    });
  });
}
