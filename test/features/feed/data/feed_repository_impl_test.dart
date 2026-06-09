import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/observability/observability.dart';
import 'package:featgg/src/features/feed/data/feed_data_source.dart';
import 'package:featgg/src/features/feed/data/feed_preview_dto.dart';
import 'package:featgg/src/features/feed/data/feed_repository_impl.dart';
import 'package:featgg/src/features/feed/data/supabase_feed_data_source.dart';
import 'package:featgg/src/features/feed/domain/feed_page.dart';
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

final class _FakeFeedDataSource implements FeedDataSource {
  _FakeFeedDataSource(this._onFetch);

  final Future<List<FeedRowDto>> Function({
    required String viewerId,
    required FeedCursor? cursor,
    required DateTime staleCutoffUtc,
    required int limit,
  })
  _onFetch;

  @override
  Future<List<FeedRowDto>> fetchPage({
    required String viewerId,
    required FeedCursor? cursor,
    required DateTime staleCutoffUtc,
    required int limit,
  }) => _onFetch(
    viewerId: viewerId,
    cursor: cursor,
    staleCutoffUtc: staleCutoffUtc,
    limit: limit,
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _steamPreview = <String, dynamic>{
  'schema_version': 1,
  'platform': 'steam',
  'title': 'TestUser',
  'subtitle': null,
  'icon_image': null,
  'hero_image': null,
  'profile_url': null,
  'stats': [],
  'last_updated': '2026-06-03T12:00:00Z',
};

FeedRowDto _row(
  String userId,
  String isoTimestamp, {
  Map<String, dynamic>? preview,
}) => FeedRowDto(
  userId: userId,
  platformWire: 'steam',
  lastUpdatedAt: isoTimestamp,
  feedPreview: preview ?? Map<String, dynamic>.from(_steamPreview),
);

List<FeedRowDto> _rows(int count) => [
  for (var i = 0; i < count; i++)
    _row('user-$i', '2026-06-0${3 - (i % 3)}T12:00:00Z'),
];

FeedRepositoryImpl _makeRepo(
  FeedDataSource source,
  _RecordingReporter reporter, {
  String? userId = 'viewer-1',
}) => FeedRepositoryImpl(source, () => userId, reporter);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('FeedRepositoryImpl.fetchFeed', () {
    test('no viewer id → Left(AuthFailure), not reported', () async {
      final source = _FakeFeedDataSource(
        ({
          required viewerId,
          required cursor,
          required staleCutoffUtc,
          required limit,
        }) async => [],
      );
      final reporter = _RecordingReporter();
      final result = await _makeRepo(
        source,
        reporter,
        userId: null,
      ).fetchFeed(cursor: null);

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, isEmpty);
    });

    test('N rows → Right(FeedPage) with N items, hasMore per limit', () async {
      // Less than kFeedPageSize → hasMore false.
      final source = _FakeFeedDataSource(
        ({
          required viewerId,
          required cursor,
          required staleCutoffUtc,
          required limit,
        }) async => _rows(5),
      );
      final reporter = _RecordingReporter();
      final result = await _makeRepo(source, reporter).fetchFeed(cursor: null);

      result.fold((f) => fail('want Right, got $f'), (page) {
        expect(page.items, hasLength(5));
        expect(page.hasMore, isFalse);
        expect(page.nextCursor, isNull);
      });
    });

    test(
      'exactly kFeedPageSize rows → hasMore true, nextCursor non-null',
      () async {
        final source = _FakeFeedDataSource(
          ({
            required viewerId,
            required cursor,
            required staleCutoffUtc,
            required limit,
          }) async => _rows(kFeedPageSize),
        );
        final reporter = _RecordingReporter();
        final result = await _makeRepo(
          source,
          reporter,
        ).fetchFeed(cursor: null);

        result.fold((f) => fail('want Right, got $f'), (page) {
          expect(page.hasMore, isTrue);
          expect(page.nextCursor, isNotNull);
        });
      },
    );

    test(
      'nextCursor matches last raw row (last_updated_at + user_id)',
      () async {
        final lastRow = _row('user-z', '2026-06-01T10:00:00Z');
        final source = _FakeFeedDataSource(
          ({
            required viewerId,
            required cursor,
            required staleCutoffUtc,
            required limit,
          }) async => [..._rows(kFeedPageSize - 1), lastRow],
        );
        final reporter = _RecordingReporter();
        final result = await _makeRepo(
          source,
          reporter,
        ).fetchFeed(cursor: null);

        result.fold((f) => fail('want Right, got $f'), (page) {
          expect(page.nextCursor?.userId, 'user-z');
          expect(
            page.nextCursor?.lastUpdatedAt,
            DateTime.parse('2026-06-01T10:00:00Z'),
          );
        });
      },
    );

    test(
      'malformed row among good rows → row dropped + reported once, page returned',
      () async {
        final badPreview = <String, dynamic>{
          'schema_version': 1,
          'platform': 'steam',
        };
        // Missing required title field — feedItemFromRowOrNull returns null.
        final badRow = FeedRowDto(
          userId: 'user-bad',
          platformWire: 'steam',
          lastUpdatedAt: '2026-06-01T00:00:00Z',
          feedPreview: badPreview,
        );
        final goodRows = _rows(3);
        final source = _FakeFeedDataSource(
          ({
            required viewerId,
            required cursor,
            required staleCutoffUtc,
            required limit,
          }) async => [...goodRows, badRow],
        );
        final reporter = _RecordingReporter();
        final result = await _makeRepo(
          source,
          reporter,
        ).fetchFeed(cursor: null);

        result.fold((f) => fail('want Right, got $f'), (page) {
          expect(page.items, hasLength(3));
        });
        expect(reporter.reported, hasLength(1));
      },
    );

    test('PostgrestException 401 → Left(AuthFailure), not reported', () async {
      final source = _FakeFeedDataSource(
        ({
          required viewerId,
          required cursor,
          required staleCutoffUtc,
          required limit,
        }) async =>
            throw PostgrestException(message: 'unauthorized', code: '401'),
      );
      final reporter = _RecordingReporter();
      final result = await _makeRepo(source, reporter).fetchFeed(cursor: null);

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, isEmpty);
    });

    test(
      'PostgrestException PGRST301 → Left(AuthFailure), not reported',
      () async {
        final source = _FakeFeedDataSource(
          ({
            required viewerId,
            required cursor,
            required staleCutoffUtc,
            required limit,
          }) async => throw PostgrestException(
            message: 'jwt expired',
            code: 'PGRST301',
          ),
        );
        final reporter = _RecordingReporter();
        final result = await _makeRepo(
          source,
          reporter,
        ).fetchFeed(cursor: null);

        result.fold(
          (f) => expect(f, isA<AuthFailure>()),
          (_) => fail('want Left'),
        );
        expect(reporter.reported, isEmpty);
      },
    );

    test('SocketException → Left(NetworkFailure), not reported', () async {
      final source = _FakeFeedDataSource(
        ({
          required viewerId,
          required cursor,
          required staleCutoffUtc,
          required limit,
        }) async => throw const SocketException('no route'),
      );
      final reporter = _RecordingReporter();
      final result = await _makeRepo(source, reporter).fetchFeed(cursor: null);

      result.fold(
        (f) => expect(f, isA<NetworkFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, isEmpty);
    });

    test('TimeoutException → Left(NetworkFailure), not reported', () async {
      final source = _FakeFeedDataSource(
        ({
          required viewerId,
          required cursor,
          required staleCutoffUtc,
          required limit,
        }) async => throw TimeoutException('timed out'),
      );
      final reporter = _RecordingReporter();
      final result = await _makeRepo(source, reporter).fetchFeed(cursor: null);

      result.fold(
        (f) => expect(f, isA<NetworkFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, isEmpty);
    });

    test('unknown exception → Left(UnexpectedFailure), reported', () async {
      final source = _FakeFeedDataSource(
        ({
          required viewerId,
          required cursor,
          required staleCutoffUtc,
          required limit,
        }) async => throw Exception('something broke'),
      );
      final reporter = _RecordingReporter();
      final result = await _makeRepo(source, reporter).fetchFeed(cursor: null);

      result.fold(
        (f) => expect(f, isA<UnexpectedFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, hasLength(1));
    });

    test('empty page → Right(FeedPage) with 0 items, hasMore false', () async {
      final source = _FakeFeedDataSource(
        ({
          required viewerId,
          required cursor,
          required staleCutoffUtc,
          required limit,
        }) async => [],
      );
      final reporter = _RecordingReporter();
      final result = await _makeRepo(source, reporter).fetchFeed(cursor: null);

      result.fold((f) => fail('want Right, got $f'), (page) {
        expect(page.items, isEmpty);
        expect(page.hasMore, isFalse);
        expect(page.nextCursor, isNull);
      });
    });

    test('staleCutoff is 30 days before clock.now()', () async {
      final fixedNow = DateTime.utc(2026, 6, 9, 12);
      DateTime? capturedCutoff;
      final source = _FakeFeedDataSource(({
        required viewerId,
        required cursor,
        required staleCutoffUtc,
        required limit,
      }) async {
        capturedCutoff = staleCutoffUtc;
        return [];
      });
      final reporter = _RecordingReporter();

      await withClock(Clock.fixed(fixedNow), () async {
        await _makeRepo(source, reporter).fetchFeed(cursor: null);
      });

      expect(
        capturedCutoff,
        DateTime.utc(2026, 6, 9, 12).subtract(const Duration(days: 30)),
      );
    });
  });
}
