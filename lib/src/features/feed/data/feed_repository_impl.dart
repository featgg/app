import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/observability/observability.dart';
import '../../connections/domain/game_card.dart';
import '../domain/feed_page.dart';
import '../domain/feed_repository.dart';
import 'feed_data_source.dart';
import 'feed_preview_dto.dart';
import 'supabase_feed_data_source.dart';

final class FeedRepositoryImpl implements FeedRepository {
  FeedRepositoryImpl(this._source, this._currentUserId, this._crashReporter);

  final FeedDataSource _source;
  final String? Function() _currentUserId;
  final CrashReporter _crashReporter;

  @override
  Future<Either<Failure, FeedPage>> fetchFeed({
    required FeedCursor? cursor,
  }) async {
    final userId = _currentUserId();
    if (userId == null) return left(const AuthFailure());

    final staleCutoff = clock.now().toUtc().subtract(kCardStaleThreshold);

    try {
      final rawRows = await _source.fetchPage(
        viewerId: userId,
        cursor: cursor,
        staleCutoffUtc: staleCutoff,
        limit: kFeedPageSize,
      );

      final items = <FeedItem>[];
      for (final row in rawRows) {
        final item = feedItemFromRowOrNull(row);
        if (item == null) {
          _crashReporter.reportError(
            Exception(
              'FeedRepositoryImpl: dropped unparseable row '
              '(platform=${row.platformWire})',
            ),
            StackTrace.current,
          );
        } else {
          items.add(item);
        }
      }

      // Cursor is derived from the last *raw* row so paging never stalls on
      // a run of bad rows — the position advances even when every mapped item
      // was dropped.
      FeedCursor? nextCursor;
      if (rawRows.isNotEmpty) {
        final last = rawRows.last;
        nextCursor = FeedCursor(
          lastUpdatedAt: DateTime.parse(last.lastUpdatedAt),
          userId: last.userId,
        );
      }

      final hasMore = rawRows.length == kFeedPageSize;

      return right(
        FeedPage(
          items: items,
          nextCursor: hasMore ? nextCursor : null,
          hasMore: hasMore,
        ),
      );
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
