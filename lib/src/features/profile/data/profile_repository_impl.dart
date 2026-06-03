import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/observability/observability.dart';
import '../domain/profile.dart';
import '../domain/profile_repository.dart';
import 'profile_data_source.dart';
import 'profile_dto.dart';

final class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(
    this._dataSource,
    this._currentUserId,
    this._crashReporter,
  );

  final ProfileDataSource _dataSource;
  // Callback so tests can control the current user without a real GoTrueClient.
  final String? Function() _currentUserId;
  final CrashReporter _crashReporter;

  @override
  Future<Either<Failure, Profile>> fetchMyProfile() async {
    try {
      final userId = _currentUserId();
      if (userId == null) return left(const AuthFailure());
      final dto = await _dataSource.fetchProfileRow(userId);
      if (dto == null) {
        // Profiles are provisioned at sign-up; a signed-in user with no row
        // is a fault, not control flow.
        throw const FormatException('no profile row for the signed-in user');
      }
      return right(profileFromDto(dto));
    } catch (e, st) {
      return left(_handleError(e, st));
    }
  }

  @override
  Future<Either<Failure, Profile>> updateMyProfile(ProfileEdit edit) async {
    try {
      final userId = _currentUserId();
      if (userId == null) return left(const AuthFailure());
      final columns = profileEditToColumns(edit);
      final dto = await _dataSource.updateProfileRow(userId, columns);
      return right(profileFromDto(dto));
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
    if (error is AuthException) {
      final status = error.statusCode;
      if (status == '401' || status == '403') return const AuthFailure();
      return UnexpectedFailure(message: error.message);
    }
    if (error is PostgrestException) {
      final code = error.code;
      // PostgREST surfaces RLS denial / JWT problems in the 401/403 class.
      if (code == '401' || code == '403' || code == 'PGRST301') {
        return const AuthFailure();
      }
      // Postgres integrity-violation class (23xxx): check, unique, not-null
      // violations are expected control flow — the backend constraint is
      // authoritative and the client surfaces the rejection as an InputFailure.
      if (code != null && code.startsWith('23')) {
        return InputFailure(message: error.message, code: code);
      }
      return UnexpectedFailure(message: error.message);
    }
    if (error is SocketException) return NetworkFailure(message: error.message);
    return UnexpectedFailure(message: error.toString());
  }
}
