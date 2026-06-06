import 'dart:async';
import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/observability/observability.dart';
import '../domain/cards_repository.dart';
import '../domain/connection.dart';
import '../domain/game_card.dart';
import '../domain/platform_descriptor.dart';
import 'cards_data_source.dart';
import 'game_card_dto.dart';

final class CardsRepositoryImpl implements CardsRepository {
  CardsRepositoryImpl(this._source, this._currentUserId, this._crashReporter);

  final CardsDataSource _source;
  final String? Function() _currentUserId;
  final CrashReporter _crashReporter;

  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) async {
    try {
      final userId = _currentUserId();
      if (userId == null) return left(const AuthFailure());
      final descriptor = platformDescriptors[platform];
      final wireValue = descriptor?.wireValue ?? platform.name;
      final dto = await _source.fetchCard(userId, wireValue);
      if (dto == null) return right(null);
      return right(gameCardFromDto(dto));
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
}
