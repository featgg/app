import 'dart:async';
import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/observability/observability.dart';
import '../domain/connection.dart';
import '../domain/connections_repository.dart';
import '../domain/platform_descriptor.dart';
import 'connection_dto.dart';
import 'connections_data_source.dart';
import 'link_account_dto.dart';

final class ConnectionsRepositoryImpl implements ConnectionsRepository {
  ConnectionsRepositoryImpl(
    this._source,
    this._currentUserId,
    this._crashReporter,
  );

  final ConnectionsDataSource _source;
  final String? Function() _currentUserId;
  final CrashReporter _crashReporter;

  @override
  Future<Either<Failure, Unit>> link({
    required Platform platform,
    required Map<String, String> formInput,
  }) async {
    final descriptor = platformDescriptors[platform];
    final builder = linkBodyBuilders[platform];
    if (descriptor == null || builder == null) {
      return left(
        const UnexpectedFailure(message: 'no link builder for platform'),
      );
    }
    try {
      final body = builder(descriptor.wireValue, formInput);
      await _source.linkAccount(body);
      return right(unit);
    } on FunctionException catch (e, st) {
      final failure = _mapFunctionException(e);
      // ALREADY_LINKED is success-equivalent at this boundary (idempotent-by-intent).
      if (failure is AlreadyLinkedFailure) return right(unit);
      if (!failure.isExpected) _crashReporter.reportError(e, st);
      return left(failure);
    } catch (e, st) {
      return left(_handleNonFunctionError(e, st));
    }
  }

  @override
  Future<Either<Failure, Unit>> unlink(Platform platform) async {
    final descriptor = platformDescriptors[platform];
    final wireValue = descriptor?.wireValue ?? platform.name;
    try {
      await _source.unlinkAccount(wireValue);
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
  Future<Either<Failure, SyncResult>> refresh(Platform platform) async {
    final descriptor = platformDescriptors[platform];
    if (descriptor == null) {
      return left(
        const UnexpectedFailure(message: 'no descriptor for platform'),
      );
    }
    try {
      final dto = await _source.syncPlatform(descriptor.syncFunctionName);
      return right(SyncResult(skipped: dto.skipped));
    } on FunctionException catch (e, st) {
      final failure = _mapFunctionException(e);
      if (!failure.isExpected) _crashReporter.reportError(e, st);
      return left(failure);
    } catch (e, st) {
      return left(_handleNonFunctionError(e, st));
    }
  }

  @override
  Future<Either<Failure, List<Connection>>> fetchMyConnections() async {
    try {
      final userId = _currentUserId();
      if (userId == null) return left(const AuthFailure());
      final dtos = await _source.fetchConnections(userId);
      return right(dtos.map(connectionFromDto).toList());
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
    if (error is AuthException) {
      final status = error.statusCode;
      if (status == '401' || status == '403') return const AuthFailure();
      return UnexpectedFailure(message: error.message);
    }
    if (error is PostgrestException) {
      final code = error.code;
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

  Failure _mapFunctionException(FunctionException e) {
    final details = e.details;
    final code = details is Map ? details['code'] as String? : null;
    final status = e.status;
    final message = details is Map ? details['message'] as String? : null;

    if (code == 'ALREADY_LINKED' || status == 409) {
      return AlreadyLinkedFailure(code: code, message: message);
    }
    if (code == 'INVALID_REQUEST' ||
        code == 'UNSUPPORTED_MEDIA_TYPE' ||
        code == 'PAYLOAD_TOO_LARGE' ||
        status == 400 ||
        status == 413 ||
        status == 415) {
      return InputFailure(code: code, message: message);
    }
    if (code == 'UNAUTHORIZED' || status == 401) {
      return AuthFailure(code: code, message: message);
    }
    if (code == 'SYNC_COOLDOWN') {
      return SyncCooldownFailure(code: code, message: message);
    }
    if (code == 'UPSTREAM_NOT_FOUND' ||
        code == 'UPSTREAM_RATE_LIMIT' ||
        code == 'UPSTREAM_FAILURE' ||
        code == 'LINKED_ACCOUNT_NOT_FOUND' ||
        code == 'MISSING_STORED_CREDENTIAL' ||
        code == 'INVALID_STORED_ROUTING') {
      return UpstreamFailure(code: code, message: message);
    }
    if (code == 'LINK_WRITE_FAILED' ||
        code == 'UNLINK_FAILED' ||
        code == 'SYNC_COMMIT_FAILED' ||
        code == 'COOLDOWN_CHECK_FAILED' ||
        code == 'SERVER_MISCONFIGURATION' ||
        code == 'INTERNAL_ERROR' ||
        status >= 500) {
      return ServerFailure(code: code, message: message);
    }
    // 429 with no recognized code — treat as cooldown (belt-and-suspenders for
    // the SYNC_COOLDOWN path where code may be absent in edge cases).
    if (status == 429) {
      return SyncCooldownFailure(code: code, message: message);
    }
    return UnexpectedFailure(message: e.toString());
  }
}
