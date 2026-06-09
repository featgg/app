import 'package:clock/clock.dart';
import 'package:featgg/src/features/feed/data/supabase_feed_data_source.dart';
import 'package:featgg/src/features/feed/domain/feed_page.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the pure query-string helper functions extracted from
/// [SupabaseFeedDataSource]. The concrete SDK builder cannot be faked under the
/// hand-rolled-fake convention (it chains return-typed builder objects),
/// so the query-string composition is extracted to pure helpers and tested
/// directly (per architecture.md § Repository pattern's SDK-fakeability note).
void main() {
  group('buildStaleWowOrFilter', () {
    test('produces expected PostgREST or-filter with clock-pinned cutoff', () {
      final fixedNow = DateTime.utc(2026, 6, 9, 12);
      final cutoff = fixedNow.subtract(const Duration(days: 30));
      final cutoffIso = cutoff.toIso8601String();

      final filter = withClock(
        Clock.fixed(fixedNow),
        () =>
            buildStaleWowOrFilter(fixedNow.subtract(const Duration(days: 30))),
      );

      expect(filter, 'platform.neq.wow_retail,last_updated_at.gte.$cutoffIso');
    });

    test('cutoff ISO string is UTC', () {
      final cutoff = DateTime.utc(2026, 5, 10, 12);
      final filter = buildStaleWowOrFilter(cutoff);
      expect(filter, contains(cutoff.toIso8601String()));
      // The cutoff must be UTC-expressed.
      expect(cutoff.isUtc, isTrue);
    });
  });

  group('buildKeysetOrFilter', () {
    test('null cursor → returns null (first page)', () {
      expect(buildKeysetOrFilter(null), isNull);
    });

    test('non-null cursor → PostgREST or-filter with lt and nested and()', () {
      final cursor = FeedCursor(
        lastUpdatedAt: DateTime.utc(2026, 6, 3, 12),
        userId: 'user-abc',
      );

      final filter = buildKeysetOrFilter(cursor);

      expect(filter, isNotNull);
      final curIso = cursor.lastUpdatedAt.toUtc().toIso8601String();
      expect(
        filter,
        'last_updated_at.lt.$curIso,and(last_updated_at.eq.$curIso,user_id.lt.user-abc)',
      );
    });

    test('filter contains the cursor userId as tiebreaker', () {
      final cursor = FeedCursor(
        lastUpdatedAt: DateTime.utc(2026, 6, 1),
        userId: 'specific-user-id',
      );
      final filter = buildKeysetOrFilter(cursor);
      expect(filter, contains('specific-user-id'));
    });

    test(
      'filter contains the cursor timestamp in both lt and eq predicates',
      () {
        final cursor = FeedCursor(
          lastUpdatedAt: DateTime.utc(2026, 6, 1, 8, 30),
          userId: 'u1',
        );
        final curIso = cursor.lastUpdatedAt.toUtc().toIso8601String();
        final filter = buildKeysetOrFilter(cursor);
        // lt predicate
        expect(filter, contains('last_updated_at.lt.$curIso'));
        // eq predicate inside the nested and()
        expect(filter, contains('last_updated_at.eq.$curIso'));
      },
    );
  });

  group('kFeedPageSize', () {
    test('is 20', () => expect(kFeedPageSize, 20));
  });
}
