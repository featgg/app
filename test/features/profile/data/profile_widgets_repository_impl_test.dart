import 'dart:async';
import 'dart:io';

import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/observability/observability.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/profile/data/profile_widget_dto.dart';
import 'package:featgg/src/features/profile/data/profile_widgets_data_source.dart';
import 'package:featgg/src/features/profile/data/profile_widgets_repository_impl.dart';
import 'package:featgg/src/features/profile/data/supabase_profile_widgets_data_source.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
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

final class _FakeDataSource implements ProfileWidgetsDataSource {
  _FakeDataSource({
    this.onFetch,
    this.onFetchFor,
    this.onInsert,
    this.onDelete,
  });

  Future<List<ProfileWidgetDto>> Function()? onFetch;

  /// Owner-aware variant: receives the recorded [userId] so a test can seed
  /// owner-only rows. Takes precedence over [onFetch] when set.
  Future<List<ProfileWidgetDto>> Function(String userId)? onFetchFor;
  Future<ProfileWidgetDto> Function(Map<String, dynamic> row)? onInsert;
  Future<void> Function(String id)? onDelete;

  Map<String, dynamic>? lastInsert;
  ({String id, Map<String, dynamic> values})? lastUpdate;
  List<({String id, int position})>? lastPositions;
  String? lastFetchUserId;

  /// The max live `position` the concrete source would read before parking.
  /// Defaults to a SPARSE band top (live rows at e.g. [0,2,4]) so the mirror
  /// proves the positive parking band sits above every current slot.
  int maxCurrentPosition = 4;

  /// Every individual position write the data source would apply, in order,
  /// so a test can prove no transient duplicate occurs among live (>= 0) rows.
  final List<({String id, int position})> positionWrites = [];

  @override
  Future<List<ProfileWidgetDto>> fetchMyWidgets(String userId) {
    lastFetchUserId = userId;
    if (onFetchFor != null) return onFetchFor!(userId);
    return (onFetch ?? () async => <ProfileWidgetDto>[])();
  }

  @override
  Future<ProfileWidgetDto> insertWidget(Map<String, dynamic> row) {
    lastInsert = row;
    return (onInsert ?? (r) async => ProfileWidgetDto.fromJson(_rowMap()))(row);
  }

  @override
  Future<void> deleteWidget(String id) => (onDelete ?? (_) async {})(id);

  @override
  Future<void> updateWidget(String id, Map<String, dynamic> values) async {
    lastUpdate = (id: id, values: values);
  }

  @override
  Future<void> updatePositions(
    List<({String id, int position})> updates,
  ) async {
    lastPositions = updates;
    // Mirror the concrete two-pass write contract via the same pure helper the
    // source uses (positive parking above [maxCurrentPosition], then the final
    // positions) so a test can prove the planned write order carries no
    // transient duplicate among live rows.
    positionWrites.addAll(reorderPositionWrites(updates, maxCurrentPosition));
  }
}

Map<String, dynamic> _rowMap({
  String id = 'w-1',
  String? platform = 'steam',
  String type = 'platform',
  int position = 0,
  bool isEnabled = true,
  String size = 'small',
  int schemaVersion = kProfileWidgetSettingsVersion,
}) => {
  'id': id,
  'platform': platform,
  'type': type,
  'position': position,
  'is_enabled': isEnabled,
  'settings': {'schema_version': schemaVersion, 'size': size},
};

ProfileWidgetDto _dto(Map<String, dynamic> map) =>
    ProfileWidgetDto.fromJson(map);

ProfileWidgetsRepositoryImpl _repo(
  ProfileWidgetsDataSource source,
  _RecordingReporter reporter, {
  String? userId = 'user-1',
}) => ProfileWidgetsRepositoryImpl(source, () => userId, reporter);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('fetchMyWidgets', () {
    test('no user session → Left(AuthFailure), not reported', () async {
      final reporter = _RecordingReporter();
      final result = await _repo(
        _FakeDataSource(),
        reporter,
        userId: null,
      ).fetchMyWidgets();

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, isEmpty);
    });

    test('forwards the signed-in user id to the data source', () async {
      final source = _FakeDataSource(onFetch: () async => <ProfileWidgetDto>[]);
      await _repo(source, _RecordingReporter()).fetchMyWidgets();

      // Without the filter the id is never threaded — this pins the
      // owner-scoped read.
      expect(source.lastFetchUserId, 'user-1');
    });

    test('returns only the owner\'s rows', () async {
      // The fake returns owner rows only when the recorded id matches; a
      // foreign id would yield foreign rows. Pins the scoping at the
      // unit-provable boundary (the real .eq SQL filter is device-provable).
      final source = _FakeDataSource(
        onFetchFor: (userId) async => userId == 'user-1'
            ? [_dto(_rowMap(id: 'owner', position: 0))]
            : [_dto(_rowMap(id: 'foreign', position: 0))],
      );
      final result = await _repo(source, _RecordingReporter()).fetchMyWidgets();

      result.fold(
        (f) => fail('want Right, got $f'),
        (widgets) => expect(widgets.map((w) => w.id), ['owner']),
      );
    });

    test('maps rows to entities preserving order', () async {
      final source = _FakeDataSource(
        onFetch: () async => [
          _dto(_rowMap(id: 'a', position: 0, size: 'small')),
          _dto(_rowMap(id: 'b', position: 1, platform: 'chess', size: 'large')),
        ],
      );
      final result = await _repo(source, _RecordingReporter()).fetchMyWidgets();

      result.fold((f) => fail('want Right, got $f'), (widgets) {
        expect(widgets.map((w) => w.id), ['a', 'b']);
        expect(widgets[0].size, ProfileWidgetSize.small);
        expect(widgets[1].platform, Platform.chess);
        expect(widgets[1].size, ProfileWidgetSize.large);
      });
    });

    test('omits a schema_version != 1 row', () async {
      final source = _FakeDataSource(
        onFetch: () async => [
          _dto(_rowMap(id: 'ok')),
          _dto(_rowMap(id: 'bad', schemaVersion: 2)),
        ],
      );
      final result = await _repo(source, _RecordingReporter()).fetchMyWidgets();

      result.fold(
        (f) => fail('want Right, got $f'),
        (widgets) => expect(widgets.map((w) => w.id), ['ok']),
      );
    });

    test('omits an unknown-type row', () async {
      final source = _FakeDataSource(
        onFetch: () async => [
          _dto(_rowMap(id: 'ok')),
          _dto(_rowMap(id: 'future', type: 'composed')),
        ],
      );
      final result = await _repo(source, _RecordingReporter()).fetchMyWidgets();

      result.fold(
        (f) => fail('want Right, got $f'),
        (widgets) => expect(widgets.map((w) => w.id), ['ok']),
      );
    });

    test('omits an unknown-platform row', () async {
      final source = _FakeDataSource(
        onFetch: () async => [
          _dto(_rowMap(id: 'ok')),
          _dto(_rowMap(id: 'bad', platform: 'nope')),
        ],
      );
      final result = await _repo(source, _RecordingReporter()).fetchMyWidgets();

      result.fold(
        (f) => fail('want Right, got $f'),
        (widgets) => expect(widgets.map((w) => w.id), ['ok']),
      );
    });

    test('PostgrestException 401 → Left(AuthFailure), not reported', () async {
      final source = _FakeDataSource(
        onFetch: () async =>
            throw PostgrestException(message: 'denied', code: '401'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(source, reporter).fetchMyWidgets();

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, isEmpty);
    });

    test('SocketException → Left(NetworkFailure), not reported', () async {
      final source = _FakeDataSource(
        onFetch: () async => throw const SocketException('offline'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(source, reporter).fetchMyWidgets();

      result.fold(
        (f) => expect(f, isA<NetworkFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, isEmpty);
    });

    test('TimeoutException → Left(NetworkFailure), not reported', () async {
      final source = _FakeDataSource(
        onFetch: () async => throw TimeoutException('slow'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(source, reporter).fetchMyWidgets();

      result.fold(
        (f) => expect(f, isA<NetworkFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, isEmpty);
    });

    test('parse fault → Left(UnexpectedFailure), reported', () async {
      final source = _FakeDataSource(
        onFetch: () async => throw const FormatException('bad row'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(source, reporter).fetchMyWidgets();

      result.fold(
        (f) => expect(f, isA<UnexpectedFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, hasLength(1));
    });
  });

  group('addPlatformWidget', () {
    test('writes the v1 settings envelope and returns the entity', () async {
      final source = _FakeDataSource(
        onInsert: (row) async => _dto(_rowMap(id: 'new', size: 'large')),
      );
      final result = await _repo(source, _RecordingReporter())
          .addPlatformWidget(
            platform: Platform.steam,
            position: 2,
            size: ProfileWidgetSize.large,
          );

      result.fold((f) => fail('want Right, got $f'), (widget) {
        expect(widget.id, 'new');
        expect(widget.size, ProfileWidgetSize.large);
      });
      final settings = source.lastInsert!['settings'] as Map<String, dynamic>;
      expect(settings['schema_version'], kProfileWidgetSettingsVersion);
      expect(settings['size'], 'large');
      expect(source.lastInsert!['type'], 'platform');
      expect(source.lastInsert!['platform'], 'steam');
      expect(source.lastInsert!['position'], 2);
      expect(source.lastInsert!['is_enabled'], true);
    });

    test(
      'constraint violation (23505) → Left(InputFailure), not reported',
      () async {
        final source = _FakeDataSource(
          onInsert: (_) async =>
              throw PostgrestException(message: 'duplicate', code: '23505'),
        );
        final reporter = _RecordingReporter();
        final result = await _repo(source, reporter).addPlatformWidget(
          platform: Platform.steam,
          position: 0,
          size: ProfileWidgetSize.small,
        );

        result.fold((f) {
          expect(f, isA<InputFailure>());
          expect(f.isExpected, isTrue);
          expect((f as InputFailure).code, '23505');
        }, (_) => fail('want Left'));
        expect(reporter.reported, isEmpty);
      },
    );

    test(
      'a check_violation (23514) → Left(InputFailure), not reported',
      () async {
        final source = _FakeDataSource(
          onInsert: (_) async =>
              throw PostgrestException(message: 'cap exceeded', code: '23514'),
        );
        final reporter = _RecordingReporter();
        final result = await _repo(source, reporter).addPlatformWidget(
          platform: Platform.steam,
          position: 0,
          size: ProfileWidgetSize.small,
        );

        result.fold((f) {
          expect(f, isA<InputFailure>());
          expect(f.isExpected, isTrue);
        }, (_) => fail('want Left'));
        expect(reporter.reported, isEmpty);
      },
    );

    test(
      'a non-integrity PostgrestException (PGRST116) → Left(UnexpectedFailure), reported',
      () async {
        final source = _FakeDataSource(
          onInsert: (_) async =>
              throw PostgrestException(message: 'no rows', code: 'PGRST116'),
        );
        final reporter = _RecordingReporter();
        final result = await _repo(source, reporter).addPlatformWidget(
          platform: Platform.steam,
          position: 0,
          size: ProfileWidgetSize.small,
        );

        result.fold(
          (f) => expect(f, isA<UnexpectedFailure>()),
          (_) => fail('want Left'),
        );
        expect(reporter.reported, hasLength(1));
      },
    );
  });

  group('mutations write the expected values', () {
    test('setSize writes the v1 envelope', () async {
      final source = _FakeDataSource();
      await _repo(
        source,
        _RecordingReporter(),
      ).setSize('w-1', ProfileWidgetSize.wide);

      final settings =
          source.lastUpdate!.values['settings'] as Map<String, dynamic>;
      expect(settings['schema_version'], kProfileWidgetSettingsVersion);
      expect(settings['size'], 'wide');
    });

    test('reorder writes a contiguous 0..n-1 sequence', () async {
      final source = _FakeDataSource();
      await _repo(source, _RecordingReporter()).reorder(['c', 'a', 'b']);

      expect(source.lastPositions, [
        (id: 'c', position: 0),
        (id: 'a', position: 1),
        (id: 'b', position: 2),
      ]);
    });

    test(
      'reorder over sparse stored positions writes a contiguous 0..n-1 with no '
      'transient duplicate',
      () async {
        // Ids modeling rows stored at sparse positions (e.g. [0,2,4], max 4);
        // a fixed positive offset could collide against the still-current 4,
        // and negative parking is rejected by the >= 0 constraint.
        final source = _FakeDataSource()..maxCurrentPosition = 4;
        await _repo(source, _RecordingReporter()).reorder(['x', 'y', 'z']);

        // (a) The final positions are the contiguous 0..n-1.
        expect(source.lastPositions, [
          (id: 'x', position: 0),
          (id: 'y', position: 1),
          (id: 'z', position: 2),
        ]);

        // (b) Every recorded write — parking included — is non-negative; the
        // positive band sits strictly above every live position.
        expect(
          source.positionWrites.every((w) => w.position >= 0),
          isTrue,
          reason: 'a parking write fell below 0',
        );

        // (c) At no point in the recorded write sequence do two rows hold the
        // same position: parking lands above the live max, disjoint from the
        // final contiguous band, regardless of sparsity.
        final heldBy = <int, String>{};
        for (final w in source.positionWrites) {
          // A live position is held by exactly one row at a time across the
          // whole write sequence; the previous holder must have already moved
          // off it before this write reuses the slot.
          final previous = heldBy[w.position];
          expect(
            previous == null || previous == w.id,
            isTrue,
            reason: 'transient duplicate at position ${w.position}',
          );
          heldBy.removeWhere((_, id) => id == w.id);
          heldBy[w.position] = w.id;
        }
      },
    );

    test('removeWidget deletes by id', () async {
      String? deleted;
      final source = _FakeDataSource(onDelete: (id) async => deleted = id);
      final result = await _repo(
        source,
        _RecordingReporter(),
      ).removeWidget('w-9');

      expect(result.isRight(), isTrue);
      expect(deleted, 'w-9');
    });

    test('a write with no user session → Left(AuthFailure)', () async {
      final result = await _repo(
        _FakeDataSource(),
        _RecordingReporter(),
        userId: null,
      ).removeWidget('w-1');

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('want Left'),
      );
    });
  });

  group('reorderPositionWrites', () {
    test('parks above the current max over sparse positions', () async {
      // Final order [(x,0),(y,1),(z,2)] computed by the repo, over live rows at
      // sparse positions [0,2,4] so the current max is 4. Negative parking
      // (the device bug) would write position < 0 and fail the >= 0 constraint.
      final updates = [
        (id: 'x', position: 0),
        (id: 'y', position: 1),
        (id: 'z', position: 2),
      ];
      final writes = reorderPositionWrites(updates, 4);

      // (a) Every write is non-negative.
      expect(writes.every((w) => w.position >= 0), isTrue);

      // (b) The parking pass sits strictly above the live max (4) and disjoint
      // from both the live set {0,2,4} and the final set {0,1,2}.
      final parking = writes.take(updates.length).toList();
      expect(parking.every((w) => w.position > 4), isTrue);
      const live = {0, 2, 4};
      expect(parking.any((w) => live.contains(w.position)), isFalse);
      expect(parking.any((w) => w.position <= 2), isFalse);
      // No duplicate parking position.
      expect(parking.map((w) => w.position).toSet(), hasLength(parking.length));

      // (c) The final pass is the contiguous 0..n-1 in order.
      expect(writes.skip(updates.length).toList(), updates);

      // (d) Replaying the full sequence over a {id -> position} model never
      // holds two live ids at the same position.
      final heldBy = <int, String>{};
      for (final w in writes) {
        final previous = heldBy[w.position];
        expect(
          previous == null || previous == w.id,
          isTrue,
          reason: 'transient duplicate at position ${w.position}',
        );
        heldBy.removeWhere((_, id) => id == w.id);
        heldBy[w.position] = w.id;
      }
    });

    test('a single update parks then writes 0', () async {
      final writes = reorderPositionWrites([(id: 'only', position: 0)], 4);
      expect(writes, [(id: 'only', position: 5), (id: 'only', position: 0)]);
    });
  });
}
