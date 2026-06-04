import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/observability/observability.dart';
import '../domain/avatar_repository.dart';
import 'avatar_dto.dart';
import 'avatar_upload_source.dart';

final class AvatarRepositoryImpl implements AvatarRepository {
  AvatarRepositoryImpl(this._source, this._crashReporter);

  final AvatarUploadSource _source;
  final CrashReporter _crashReporter;

  @override
  Future<Either<Failure, String>> uploadAvatar({
    required Uint8List bytes,
    required String contentType,
  }) async {
    try {
      final dto = await _source.uploadAvatar(bytes, contentType);
      return right(dto.avatarUrl);
    } catch (e, st) {
      return left(_handleError(e, st));
    }
  }

  Failure _handleError(Object error, StackTrace st) {
    final failure = _mapError(error);
    if (!failure.isExpected) _crashReporter.reportError(error, st);
    return failure;
  }

  Failure _mapError(Object error) {
    if (error is FunctionException) {
      return _mapFunctionException(error);
    }
    if (error is SocketException) return NetworkFailure(message: error.message);
    if (error is TimeoutException) {
      return NetworkFailure(message: error.message);
    }
    return UnexpectedFailure(message: error.toString());
  }

  Failure _mapFunctionException(FunctionException e) {
    // Branch on the stable code token first; fall back to HTTP status.
    final details = e.details;
    final code = details is Map ? details['code'] as String? : null;
    final status = e.status;

    if (code == 'MODERATION_REJECTED' || status == 422) {
      final categories = _parseCategories(details);
      return ModerationRejectedFailure(
        categories: categories,
        code: code,
        message: details is Map ? details['message'] as String? : null,
      );
    }
    if (code == 'PAYLOAD_TOO_LARGE' || status == 413) {
      return InputFailure(
        code: code,
        message: details is Map ? details['message'] as String? : null,
      );
    }
    if (code == 'UNSUPPORTED_MEDIA_TYPE' || status == 415) {
      return InputFailure(
        code: code,
        message: details is Map ? details['message'] as String? : null,
      );
    }
    if (code == 'UNAUTHORIZED' || status == 401) {
      return AuthFailure(
        code: code,
        message: details is Map ? details['message'] as String? : null,
      );
    }
    if (code == 'AVATAR_COOLDOWN' || status == 429) {
      return RateLimitFailure(
        code: code,
        message: details is Map ? details['message'] as String? : null,
      );
    }
    if (code == 'MODERATION_UNAVAILABLE' || status >= 500) {
      return ModerationUnavailableFailure(
        code: code,
        message: details is Map ? details['message'] as String? : null,
      );
    }
    // Every documented avatar error code is matched above; this sink
    // crash-reports only genuinely unknown codes.
    return UnexpectedFailure(message: e.toString());
  }

  List<String> _parseCategories(Object? details) {
    if (details is! Map) return const [];
    try {
      final dto = AvatarModerationDetailsDto.fromJson(
        Map<String, dynamic>.from(details),
      );
      return dto.categories;
    } catch (_) {
      return const [];
    }
  }
}
