import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/observability/observability.dart';
import 'package:featgg/src/features/settings/data/account_deletion_data_source.dart';
import 'package:featgg/src/features/settings/data/account_deletion_dto.dart';
import 'package:featgg/src/features/settings/data/account_deletion_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fixture_loader.dart';

/// Contract layer for account deletion: recorded real `delete-account` /
/// `cancel-deletion` responses are replayed through the prod DTO factories and
/// [AccountDeletionRepositoryImpl] mapper, enforcing `account-deletion.md`.
///
/// Inputs come from recorded fixtures, not invented values. While a fixture is
/// a placeholder the loader fails loudly (red by design); these assertions go
/// green only once a human drops cleaned real data.

final class _RecordingReporter implements CrashReporter {
  final List<Object> reported = [];

  @override
  Future<void> reportError(Object error, StackTrace? stackTrace) async {
    reported.add(error);
  }
}

/// A fixture-fed [AccountDeletionDataSource]. On 200 it returns the real DTO
/// factory output (so a renamed/missing field throws exactly as in prod); on a
/// 4xx/5xx it throws the same [FunctionException] shape the prod data source
/// throws (`details: payload`, `reasonPhrase: payload['message']`).
final class _FixtureDataSource implements AccountDeletionDataSource {
  _FixtureDataSource({
    this.requestFixture,
    this.confirmFixture,
    this.cancelFixture,
  });

  final RecordedFixture? requestFixture;
  final RecordedFixture? confirmFixture;
  final RecordedFixture? cancelFixture;

  @override
  Future<DeletionRequestDto> requestDeletion() async {
    final f = requestFixture!;
    if (f.status == 200) return DeletionRequestDto.fromJson(f.payload);
    throw _asFunctionException(f);
  }

  @override
  Future<DeletionConfirmDto> confirmDeletion(String code) async {
    final f = confirmFixture!;
    if (f.status == 200) return DeletionConfirmDto.fromJson(f.payload);
    throw _asFunctionException(f);
  }

  @override
  Future<DeletionCancelDto> cancelDeletion() async {
    final f = cancelFixture!;
    if (f.status == 200) return DeletionCancelDto.fromJson(f.payload);
    throw _asFunctionException(f);
  }

  @override
  Future<DeletionStatusDto> fetchDeletionStatus() async =>
      throw UnimplementedError('not covered by a recorded fixture');
}

FunctionException _asFunctionException(RecordedFixture f) => FunctionException(
  status: f.status ?? 500,
  details: f.payload,
  reasonPhrase: f.payload['message'] as String?,
);

({AccountDeletionRepositoryImpl repo, _RecordingReporter reporter}) _subject(
  _FixtureDataSource source,
) {
  final reporter = _RecordingReporter();
  return (
    repo: AccountDeletionRepositoryImpl(source, reporter),
    reporter: reporter,
  );
}

const _dir = 'test/contract/fixtures/account_deletion';

void main() {
  group('account deletion — recorded contract', () {
    test('request_success → Right(unit); parses {success, otp_sent}', () async {
      final s = _subject(
        _FixtureDataSource(
          requestFixture: loadRecordedFixture('$_dir/request_success.json'),
        ),
      );
      final result = await s.repo.requestDeletion();
      expect(result.isRight(), isTrue);
    });

    test(
      'confirm_success → Right(DeletionSchedule) with parsed UTC date',
      () async {
        final fixture = loadRecordedFixture('$_dir/confirm_success.json');
        final s = _subject(_FixtureDataSource(confirmFixture: fixture));
        final result = await s.repo.confirmDeletion('123456');
        final schedule = result.fold((_) => null, (r) => r);
        expect(schedule, isNotNull);
        final expected = DateTime.parse(
          fixture.payload['deletion_scheduled_at'] as String,
        ).toUtc();
        expect(schedule!.scheduledAt, expected);
        expect(schedule.scheduledAt.isUtc, isTrue);
      },
    );

    test('cancel_success → Right(unit); parses {success, cancelled}', () async {
      final s = _subject(
        _FixtureDataSource(
          cancelFixture: loadRecordedFixture('$_dir/cancel_success.json'),
        ),
      );
      final result = await s.repo.cancelDeletion();
      expect(result.isRight(), isTrue);
    });

    test('request_rate_limited (429) → AuthRateLimitFailure carrying the '
        'documented code, expected, not crash-reported', () async {
      final fixture = loadRecordedFixture('$_dir/request_rate_limited.json');
      final s = _subject(_FixtureDataSource(requestFixture: fixture));
      final failure = (await s.repo.requestDeletion()).fold(
        (f) => f,
        (_) => null,
      );
      expect(failure, isA<AuthRateLimitFailure>());
      expect(failure!.isExpected, isTrue);
      // account-deletion.md pins the rate-limit token; assert the documented
      // code rather than echoing the fixture, so a renamed code fails here.
      expect(failure.code, 'OTP_RATE_LIMIT');
      expect(s.reporter.reported, isEmpty);
    });

    test('confirm_invalid_otp (401) → InputFailure (not AuthFailure), not '
        'crash-reported', () async {
      final s = _subject(
        _FixtureDataSource(
          confirmFixture: loadRecordedFixture('$_dir/confirm_invalid_otp.json'),
        ),
      );
      final failure = (await s.repo.confirmDeletion(
        '000000',
      )).fold((f) => f, (_) => null);
      expect(failure, isA<InputFailure>());
      expect(s.reporter.reported, isEmpty);
    });

    test(
      'request_delete_failed (500) → ServerFailure, crash-reported',
      () async {
        final s = _subject(
          _FixtureDataSource(
            requestFixture: loadRecordedFixture(
              '$_dir/request_delete_failed.json',
            ),
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
  });
}
