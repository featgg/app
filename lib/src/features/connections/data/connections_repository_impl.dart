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
    late final Map<String, dynamic> body;
    try {
      body = builder(descriptor.wireValue, formInput);
      await _source.linkAccount(body);
      return right(unit);
    } on FunctionException catch (e, st) {
      final failure = _mapFunctionException(e);
      if (failure is AlreadyLinkedFailure) {
        // ALREADY_LINKED covers both a same-account re-link (idempotent success)
        // and the submitted account being linked elsewhere — to another profile,
        // or a different account already holding the caller's single per-platform
        // slot. The code cannot distinguish them, so confirm the caller already
        // has THIS account linked before reporting success: a match means the
        // link intent is satisfied; no match means it did not occur.
        if (await _isSameAccountLinked(descriptor.wireValue, body)) {
          return right(unit);
        }
        return left(failure);
      }
      if (!failure.isExpected) _crashReporter.reportError(e, st);
      return left(failure);
    } catch (e, st) {
      return left(_handleNonFunctionError(e, st));
    }
  }

  /// Re-reads the caller's own connections and confirms the submitted identity
  /// already occupies the [wireValue] slot — disambiguating a 409: a
  /// same-account re-link returns true (idempotent success); a different
  /// account, empty slot, or fetch fault returns false so the original failure
  /// is surfaced.
  ///
  /// Matches on `remote_id` for remote-id platforms, or on `metadata` equality
  /// for metadata platforms, keyed by [body] shape.
  Future<bool> _isSameAccountLinked(
    String wireValue,
    Map<String, dynamic> body,
  ) async {
    try {
      final dtos = await _source.fetchConnections();
      return dtos.any((d) {
        if (d.platform != wireValue) return false;
        if (body.containsKey('remote_id')) {
          return d.remoteId == body['remote_id'];
        }
        if (body.containsKey('metadata')) {
          final submitted = body['metadata'] as Map<String, dynamic>?;
          if (submitted == null || d.metadata == null) return false;
          // Compare every key in the submitted metadata against the stored map.
          return submitted.entries.every((e) => d.metadata![e.key] == e.value);
        }
        return false;
      });
    } catch (_) {
      return false;
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
      final dtos = await _source.fetchConnections();
      final connections = <Connection>[];
      for (final dto in dtos) {
        final connection = connectionFromDtoOrNull(dto);
        if (connection == null) {
          // An unrecognised platform token is undocumented backend drift, not a
          // user error. Drop the row so the remaining connections still render
          // (one bad row must not blank the whole screen), but report it so the
          // drift stays observable instead of vanishing silently.
          _crashReporter.reportError(
            FormatException('unknown connection platform: ${dto.platform}'),
            StackTrace.current,
          );
          continue;
        }
        connections.add(connection);
      }
      return right(connections);
    } catch (e, st) {
      return left(_handleNonFunctionError(e, st));
    }
  }

  @override
  Future<Either<Failure, RefreshAllResult>> refreshAll() async {
    try {
      final dto = await _source.refreshAll();
      final outcomes = <RefreshOutcome>[];
      for (final entry in dto.results) {
        final platform = _platformFromWire(entry.platform);
        if (platform == null) continue; // drop unknown platforms defensively
        outcomes.add(
          RefreshOutcome(
            platform: platform,
            status: _refreshStatusFromWire(entry.status),
          ),
        );
      }
      return right(RefreshAllResult(outcomes: outcomes));
    } on FunctionException catch (e, st) {
      final failure = _mapFunctionException(e);
      if (!failure.isExpected) _crashReporter.reportError(e, st);
      return left(failure);
    } catch (e, st) {
      return left(_handleNonFunctionError(e, st));
    }
  }

  /// Reverse-maps a wire platform token to the [Platform] enum value, or null
  /// when the token is unrecognised (forward-compat: drop unknown platforms).
  Platform? _platformFromWire(String wire) {
    for (final entry in platformDescriptors.entries) {
      if (entry.value.wireValue == wire) return entry.key;
    }
    return null;
  }

  /// Maps a wire `status` token to [RefreshStatus]. Unknown tokens map to
  /// [RefreshStatus.failed] so a future new status never crashes the
  /// background path.
  RefreshStatus _refreshStatusFromWire(String wire) => switch (wire) {
    'refreshed' => RefreshStatus.refreshed,
    'skipped_unchanged' => RefreshStatus.skippedUnchanged,
    'skipped_cooldown' => RefreshStatus.skippedCooldown,
    'failed' => RefreshStatus.failed,
    _ => RefreshStatus.failed,
  };

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

    // Response headers are discarded by the SDK (FunctionException exposes only
    // status, details, and reasonPhrase). `details` IS the decoded JSON body for
    // application/json responses, so `retry_after` is readable from it when
    // present. The `refresh-all` contract documents `retry_after` in the body;
    // `sync-<platform>` documents `Retry-After` only as a header (no body field).
    // Read `retry_after` when present and use it; fall back to the caller's fixed
    // window when absent.
    final retryAfterRaw = details is Map ? details['retry_after'] : null;
    final retryAfterSeconds = switch (retryAfterRaw) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v),
      _ => null,
    };

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
    if (code == 'SYNC_COOLDOWN' || code == 'REFRESH_COOLDOWN') {
      return SyncCooldownFailure(
        code: code,
        message: message,
        retryAfterSeconds: retryAfterSeconds,
      );
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
    // the SYNC_COOLDOWN/REFRESH_COOLDOWN path where code may be absent in edge
    // cases).
    if (status == 429) {
      return SyncCooldownFailure(
        code: code,
        message: message,
        retryAfterSeconds: retryAfterSeconds,
      );
    }
    return UnexpectedFailure(message: e.toString());
  }
}
