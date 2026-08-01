import 'dart:async';
import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/observability/observability.dart';
import '../domain/account_deletion.dart';
import '../domain/account_deletion_repository.dart';
import 'account_deletion_data_source.dart';

final class AccountDeletionRepositoryImpl implements AccountDeletionRepository {
  AccountDeletionRepositoryImpl(this._source, this._crashReporter);

  final AccountDeletionDataSource _source;
  final CrashReporter _crashReporter;

  @override
  Future<Either<Failure, Unit>> requestDeletion() async {
    try {
      await _source.requestDeletion();
      return right(unit);
    } on FunctionException catch (e, st) {
      final failure = _mapFunctionException(e);
      if (!failure.isExpected) _crashReporter.reportError(e, st);
      return left(failure);
    } catch (e, st) {
      return left(_handleNonFunctionError(e, st));
    }
  }

  @override
  Future<Either<Failure, DeletionSchedule>> confirmDeletion(String code) async {
    try {
      final dto = await _source.confirmDeletion(code);
      final scheduledAt = DateTime.parse(dto.deletionScheduledAt).toUtc();
      return right(DeletionSchedule(scheduledAt: scheduledAt));
    } on FunctionException catch (e, st) {
      final failure = _mapFunctionException(e);
      if (!failure.isExpected) _crashReporter.reportError(e, st);
      return left(failure);
    } catch (e, st) {
      return left(_handleNonFunctionError(e, st));
    }
  }

  @override
  Future<Either<Failure, Unit>> cancelDeletion() async {
    try {
      await _source.cancelDeletion();
      return right(unit);
    } on FunctionException catch (e, st) {
      final failure = _mapFunctionException(e);
      if (!failure.isExpected) _crashReporter.reportError(e, st);
      return left(failure);
    } catch (e, st) {
      return left(_handleNonFunctionError(e, st));
    }
  }

  @override
  Future<Either<Failure, DeletionStatus>> fetchDeletionStatus() async {
    try {
      final dto = await _source.fetchDeletionStatus();
      final raw = dto.requestedAt;
      return right(
        DeletionStatus(
          requestedAt: raw == null ? null : DateTime.parse(raw).toUtc(),
        ),
      );
    } catch (e, st) {
      return left(_handleNonFunctionError(e, st));
    }
  }

  Failure _handleNonFunctionError(Object error, StackTrace st) {
    final failure = _mapNonFunctionError(error);
    if (!failure.isExpected) _crashReporter.reportError(error, st);
    return failure;
  }

  Failure _mapNonFunctionError(Object error) {
    if (error is PostgrestException) {
      final code = error.code;
      // The data API surfaces access denials and dead tokens as 401/403.
      if (code == '401' || code == '403' || code == 'PGRST301') {
        return const AuthFailure();
      }
      return UnexpectedFailure(message: error.message);
    }
    if (error is SocketException) return NetworkFailure(message: error.message);
    if (error is TimeoutException) {
      return NetworkFailure(message: error.message);
    }
    return UnexpectedFailure(message: error.toString());
  }

  /// Maps a [FunctionException] to a [Failure].
  ///
  /// Code token is checked BEFORE HTTP status because INVALID_OTP and
  /// UNAUTHORIZED both arrive as 401 but mean different things: INVALID_OTP is
  /// a wrong/expired code (InputFailure, user retries); UNAUTHORIZED is a dead
  /// session (AuthFailure, re-auth). Checking code first ensures the correct
  /// branch is taken regardless of status.
  Failure _mapFunctionException(FunctionException e) {
    final details = e.details;
    final code = details is Map ? details['code'] as String? : null;
    final status = e.status;
    final message = details is Map ? details['message'] as String? : null;

    // INVALID_OTP must be checked before the 401→AuthFailure fallback.
    if (code == 'INVALID_OTP') {
      return InputFailure(code: code, message: message);
    }
    if (code == 'INVALID_REQUEST' || status == 400) {
      return InputFailure(code: code, message: message);
    }
    if (code == 'UNAUTHORIZED' || status == 401) {
      return AuthFailure(code: code, message: message);
    }
    if (code == 'OTP_RATE_LIMIT' || status == 429) {
      return AuthRateLimitFailure(code: code, message: message);
    }
    if (code == 'ACCOUNT_DELETE_FAILED') {
      return ServerFailure(code: code, message: message);
    }
    if (code == 'INTERNAL_ERROR' || status >= 500) {
      return ServerFailure(code: code, message: message);
    }
    return UnexpectedFailure(message: e.toString());
  }
}
