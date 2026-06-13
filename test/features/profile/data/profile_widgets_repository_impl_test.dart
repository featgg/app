import 'dart:async';
import 'dart:io';

import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/observability/observability.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/profile/data/profile_widget_dto.dart';
import 'package:featgg/src/features/profile/data/profile_widgets_data_source.dart';
import 'package:featgg/src/features/profile/data/profile_widgets_repository_impl.dart';
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
    // Mirror the concrete two-pass write contract (negative parking, then the
    // final positions) so a test can prove the planned write order carries no
    // transient duplicate among live rows.
    for (var i = 0; i < updates.length; i++) {
      positionWrites.add((id: updates[i].id, position: -1 - i));
    }
    for (final update in updates) {
      positionWrites.add((id: update.id, position: update.position));
    }
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

      // Without the filter the id is never threaded — this pins F1.
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

    test('unique-constraint fault → Left(UnexpectedFailure)', () async {
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

      result.fold(
        (f) => expect(f, isA<UnexpectedFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, hasLength(1));
    });
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

    test('setEnabled writes is_enabled', () async {
      final source = _FakeDataSource();
      await _repo(source, _RecordingReporter()).setEnabled('w-1', false);

      expect(source.lastUpdate!.values['is_enabled'], false);
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
        // Ids modeling rows stored at sparse positions (e.g. [0,2,4]); the old
        // [n,2n) parking would collide against the still-current 4.
        final source = _FakeDataSource();
        await _repo(source, _RecordingReporter()).reorder(['x', 'y', 'z']);

        // (a) The final positions are the contiguous 0..n-1.
        expect(source.lastPositions, [
          (id: 'x', position: 0),
          (id: 'y', position: 1),
          (id: 'z', position: 2),
        ]);

        // (b) At no point in the recorded write sequence do two live (>= 0)
        // rows hold the same position — parking uses negative values disjoint
        // from every current position regardless of sparsity.
        final liveByPosition = <int, String>{};
        for (final w in source.positionWrites) {
          if (w.position < 0) continue; // parked rows are never live
          // A live position is held by exactly one row at a time across the
          // whole write sequence; the previous holder must have already been
          // parked (left the live set) before this write.
          expect(
            liveByPosition.containsKey(w.position),
            isFalse,
            reason: 'transient duplicate at live position ${w.position}',
          );
          liveByPosition[w.position] = w.id;
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
      ).setEnabled('w-1', true);

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('want Left'),
      );
    });
  });
}
