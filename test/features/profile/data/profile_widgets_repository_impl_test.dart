import 'dart:async';
import 'dart:io';

import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/observability/observability.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/profile/data/profile_widget_dto.dart';
import 'package:featgg/src/features/profile/domain/art_selection.dart';
import 'package:featgg/src/features/profile/domain/collection_selection.dart';
import 'package:featgg/src/features/profile/data/profile_widgets_data_source.dart';
import 'package:featgg/src/features/profile/data/profile_widgets_repository_impl.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/showcase_selection.dart';
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
  _FakeDataSource({this.onFetch, this.onFetchFor, this.onInsert});

  Future<List<ProfileWidgetDto>> Function()? onFetch;

  /// Owner-aware variant: receives the recorded [userId] so a test can seed
  /// owner-only rows. Takes precedence over [onFetch] when set.
  Future<List<ProfileWidgetDto>> Function(String userId)? onFetchFor;
  Future<ProfileWidgetDto> Function(Map<String, dynamic> row)? onInsert;
  Future<void> Function(String id)? onDelete;

  /// When set, `updateWidget` delegates here so a test can inject a failure.
  Future<void> Function(String id, Map<String, dynamic> values)? onUpdate;

  Map<String, dynamic>? lastInsert;
  ({String id, Map<String, dynamic> values})? lastUpdate;
  String? lastFetchUserId;

  @override
  Future<List<ProfileWidgetDto>> fetchMyWidgets(String userId) {
    lastFetchUserId = userId;
    if (onFetchFor != null) return onFetchFor!(userId);
    return (onFetch ?? () async => <ProfileWidgetDto>[])();
  }

  @override
  Future<List<ProfileWidgetDto>> fetchPublicWidgets(String userId) {
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
    if (onUpdate != null) await onUpdate!(id, values);
  }
}

Map<String, dynamic> _rowMap({
  String id = 'w-1',
  String? platform = 'steam',
  String type = 'platform',
  int position = 0,
  bool isEnabled = true,
  int schemaVersion = kProfileWidgetSettingsVersion,
}) => {
  'id': id,
  'platform': platform,
  'type': type,
  'position': position,
  'is_enabled': isEnabled,
  'settings': {'schema_version': schemaVersion},
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
          _dto(_rowMap(id: 'a', position: 0)),
          _dto(_rowMap(id: 'b', position: 1, platform: 'chess')),
        ],
      );
      final result = await _repo(source, _RecordingReporter()).fetchMyWidgets();

      result.fold((f) => fail('want Right, got $f'), (widgets) {
        expect(widgets.map((w) => w.id), ['a', 'b']);
        expect(widgets[1].platform, Platform.chess);
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

  group('fetchPublicWidgets', () {
    test('returns mapped rows with NO auth gate (null user session)', () async {
      // The public read does not gate on a current session — it succeeds even
      // when _currentUserId is null, unlike the owner read.
      final source = _FakeDataSource(
        onFetch: () async => [
          _dto(_rowMap(id: 'a', position: 0)),
          _dto(_rowMap(id: 'b', position: 1, platform: 'chess')),
        ],
      );
      final result = await _repo(
        source,
        _RecordingReporter(),
        userId: null,
      ).fetchPublicWidgets('owner-2');

      result.fold((f) => fail('want Right, got $f'), (widgets) {
        expect(widgets.map((w) => w.id), ['a', 'b']);
      });
    });

    test('scopes the read to the supplied target user id', () async {
      final source = _FakeDataSource(onFetch: () async => <ProfileWidgetDto>[]);
      await _repo(source, _RecordingReporter()).fetchPublicWidgets('owner-2');

      expect(source.lastFetchUserId, 'owner-2');
    });

    test('a private/non-existent profile (no rows) → Right([])', () async {
      final source = _FakeDataSource(onFetch: () async => <ProfileWidgetDto>[]);
      final result = await _repo(
        source,
        _RecordingReporter(),
      ).fetchPublicWidgets('owner-2');

      result.fold(
        (f) => fail('want Right, got $f'),
        (widgets) => expect(widgets, isEmpty),
      );
    });

    test('soft-drops unknown-kind / wrong-version rows', () async {
      final source = _FakeDataSource(
        onFetch: () async => [
          _dto(_rowMap(id: 'ok')),
          _dto(_rowMap(id: 'badVersion', schemaVersion: 2)),
          _dto(_rowMap(id: 'badPlatform', platform: 'nope')),
        ],
      );
      final result = await _repo(
        source,
        _RecordingReporter(),
      ).fetchPublicWidgets('owner-2');

      result.fold(
        (f) => fail('want Right, got $f'),
        (widgets) => expect(widgets.map((w) => w.id), ['ok']),
      );
    });

    test('SocketException → Left(NetworkFailure), not reported', () async {
      final source = _FakeDataSource(
        onFetch: () async => throw const SocketException('offline'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
      ).fetchPublicWidgets('owner-2');

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
      final result = await _repo(
        source,
        reporter,
      ).fetchPublicWidgets('owner-2');

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
        onInsert: (row) async => _dto(_rowMap(id: 'new')),
      );
      final result = await _repo(
        source,
        _RecordingReporter(),
      ).addPlatformWidget(platform: Platform.steam, position: 2);

      result.fold((f) => fail('want Right, got $f'), (widget) {
        expect(widget.id, 'new');
      });
      final settings = source.lastInsert!['settings'] as Map<String, dynamic>;
      expect(settings['schema_version'], kProfileWidgetSettingsVersion);
      expect(source.lastInsert!['type'], 'platform');
      expect(source.lastInsert!['platform'], 'steam');
      expect(source.lastInsert!['position'], 2);
      expect(source.lastInsert!['is_enabled'], true);
    });

    test('inserts above a row the read hides, not onto its position', (() async {
      // A row that fails to resolve — a retired kind here — is omitted from the
      // read but still holds its position, which is unique per user. The caller
      // computes its next position from what it can see, so honoring that guess
      // verbatim would collide with the hidden row and be rejected.
      final source = _FakeDataSource(
        onFetch: () async => [
          _dto(_rowMap(id: 'visible', position: 0)),
          _dto(_rowMap(id: 'hidden', type: 'template', position: 7)),
        ],
        onInsert: (row) async => _dto(_rowMap(id: 'new')),
      );
      final result = await _repo(
        source,
        _RecordingReporter(),
      ).addPlatformWidget(platform: Platform.steam, position: 1);

      expect(result.isRight(), isTrue);
      expect(source.lastInsert!['position'], 8);
    }));

    test(
      'constraint violation (23505) → Left(InputFailure), not reported',
      () async {
        final source = _FakeDataSource(
          onInsert: (_) async =>
              throw PostgrestException(message: 'duplicate', code: '23505'),
        );
        final reporter = _RecordingReporter();
        final result = await _repo(
          source,
          reporter,
        ).addPlatformWidget(platform: Platform.steam, position: 0);

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
        final result = await _repo(
          source,
          reporter,
        ).addPlatformWidget(platform: Platform.steam, position: 0);

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
        final result = await _repo(
          source,
          reporter,
        ).addPlatformWidget(platform: Platform.steam, position: 0);

        result.fold(
          (f) => expect(f, isA<UnexpectedFailure>()),
          (_) => fail('want Left'),
        );
        expect(reporter.reported, hasLength(1));
      },
    );
  });

  group('addShowcaseWidget', () {
    test('writes the showcase envelope and maps the row', () async {
      final source = _FakeDataSource(
        onInsert: (row) async => _dto({
          'id': 'sc',
          'platform': 'steam',
          'type': 'showcase',
          'position': 3,
          'is_enabled': true,
          'settings': {
            'schema_version': kProfileWidgetSettingsVersion,
            'size': 'small',
            'showcase': {'game': '730', 'hero': 'hours'},
          },
        }),
      );
      final result = await _repo(source, _RecordingReporter())
          .addShowcaseWidget(
            platform: Platform.steam,
            selection: const ShowcaseSelection(gameRef: '730'),
            position: 3,
          );

      result.fold((f) => fail('want Right, got $f'), (widget) {
        expect(widget.id, 'sc');
        expect(widget.kind, ProfileWidgetKind.showcase);
        expect(widget.platform, Platform.steam);
        expect(widget.showcaseSelection.gameRef, '730');
      });

      // The captured write is the personalization.md showcase contract: a
      // non-null Steam platform plus the showcase settings sub-object.
      expect(source.lastInsert!['type'], 'showcase');
      expect(source.lastInsert!['platform'], 'steam');
      expect(source.lastInsert!['position'], 3);
      expect(source.lastInsert!['is_enabled'], true);
      final settings = source.lastInsert!['settings'] as Map<String, dynamic>;
      expect(settings['schema_version'], kProfileWidgetSettingsVersion);
      final showcase = settings['showcase'] as Map<String, dynamic>;
      expect(showcase['game'], '730');
      expect(showcase['hero'], 'hours');
    });

    test('a 23xxx rejection → Left(InputFailure), not reported', () async {
      // A stale-snapshot position collision or the per-user cap surfaces as a
      // 23xxx violation; the backend constraint stays authoritative.
      final source = _FakeDataSource(
        onInsert: (_) async =>
            throw PostgrestException(message: 'duplicate', code: '23505'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(source, reporter).addShowcaseWidget(
        platform: Platform.steam,
        selection: const ShowcaseSelection(gameRef: '730'),
        position: 0,
      );

      result.fold((f) {
        expect(f, isA<InputFailure>());
        expect(f.isExpected, isTrue);
      }, (_) => fail('want Left'));
      expect(reporter.reported, isEmpty);
    });
  });

  group('addCollectionWidget', () {
    test('writes type collection, null platform, and the games/title', () async {
      final source = _FakeDataSource(
        onInsert: (row) async => _dto({
          'id': 'col',
          'platform': null,
          'type': 'collection',
          'position': 3,
          'is_enabled': true,
          'settings': {
            'schema_version': kProfileWidgetSettingsVersion,
            'size': 'wide',
            'collection': {
              'games': ['730', '570', '440'],
              'title': 'collectionTitleFavorites',
            },
          },
        }),
      );
      final result = await _repo(source, _RecordingReporter())
          .addCollectionWidget(
            selection: const CollectionSelection(
              gameRefs: ['730', '570', '440'],
              titleKey: 'collectionTitleFavorites',
            ),
            position: 3,
          );

      result.fold((f) => fail('want Right, got $f'), (widget) {
        expect(widget.id, 'col');
        expect(widget.kind, ProfileWidgetKind.collection);
        expect(widget.platform, isNull);
        expect(widget.collectionSelection.gameRefs, ['730', '570', '440']);
      });

      // The captured write is the personalization.md collection contract: a null
      // platform (binding) plus the collection settings sub-object.
      expect(source.lastInsert!['type'], 'collection');
      expect(source.lastInsert!['platform'], isNull);
      expect(source.lastInsert!['position'], 3);
      expect(source.lastInsert!['is_enabled'], true);
      final settings = source.lastInsert!['settings'] as Map<String, dynamic>;
      expect(settings['schema_version'], kProfileWidgetSettingsVersion);
      final collection = settings['collection'] as Map<String, dynamic>;
      expect(collection['games'], ['730', '570', '440']);
      expect(collection['title'], 'collectionTitleFavorites');
    });

    test('a 23xxx rejection → Left(InputFailure), not reported', () async {
      final source = _FakeDataSource(
        onInsert: (_) async =>
            throw PostgrestException(message: 'cap exceeded', code: '23514'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(source, reporter).addCollectionWidget(
        selection: const CollectionSelection(
          gameRefs: ['730', '570', '440'],
          titleKey: 'collectionTitleFavorites',
        ),
        position: 0,
      );

      result.fold((f) {
        expect(f, isA<InputFailure>());
        expect(f.isExpected, isTrue);
      }, (_) => fail('want Left'));
      expect(reporter.reported, isEmpty);
    });
  });

  group('addGameCollectorWidget', () {
    test('writes type game_collector, a Steam platform, and a size-only '
        'envelope', () async {
      final source = _FakeDataSource(
        onInsert: (row) async => _dto({
          'id': 'gc',
          'platform': 'steam',
          'type': 'game_collector',
          'position': 4,
          'is_enabled': true,
          'settings': {
            'schema_version': kProfileWidgetSettingsVersion,
            'size': 'small',
          },
        }),
      );
      final result = await _repo(
        source,
        _RecordingReporter(),
      ).addGameCollectorWidget(platform: Platform.steam, position: 4);

      result.fold((f) => fail('want Right, got $f'), (widget) {
        expect(widget.id, 'gc');
        expect(widget.kind, ProfileWidgetKind.gameCollector);
        expect(widget.platform, Platform.steam);
      });

      // The captured write is the personalization.md game_collector contract: a
      // non-null Steam platform and a bare envelope (no selection
      // sub-object).
      expect(source.lastInsert!['type'], 'game_collector');
      expect(source.lastInsert!['platform'], 'steam');
      expect(source.lastInsert!['position'], 4);
      expect(source.lastInsert!['is_enabled'], true);
      final settings = source.lastInsert!['settings'] as Map<String, dynamic>;
      expect(settings['schema_version'], kProfileWidgetSettingsVersion);
      // Size-only: no showcase/collection/game_collector sub-object is written.
      expect(settings.containsKey('showcase'), isFalse);
      expect(settings.containsKey('collection'), isFalse);
      expect(settings.containsKey('game_collector'), isFalse);
    });

    test('a 23xxx rejection → Left(InputFailure), not reported', () async {
      final source = _FakeDataSource(
        onInsert: (_) async =>
            throw PostgrestException(message: 'cap exceeded', code: '23514'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
      ).addGameCollectorWidget(platform: Platform.steam, position: 0);

      result.fold((f) {
        expect(f, isA<InputFailure>());
        expect(f.isExpected, isTrue);
      }, (_) => fail('want Left'));
      expect(reporter.reported, isEmpty);
    });
  });

  group('addCompletionistWidget', () {
    test('writes type completionist, a Steam platform, and a size-only '
        'envelope', () async {
      final source = _FakeDataSource(
        onInsert: (row) async => _dto({
          'id': 'cp',
          'platform': 'steam',
          'type': 'completionist',
          'position': 4,
          'is_enabled': true,
          'settings': {
            'schema_version': kProfileWidgetSettingsVersion,
            'size': 'small',
          },
        }),
      );
      final result = await _repo(
        source,
        _RecordingReporter(),
      ).addCompletionistWidget(platform: Platform.steam, position: 4);

      result.fold((f) => fail('want Right, got $f'), (widget) {
        expect(widget.id, 'cp');
        expect(widget.kind, ProfileWidgetKind.completionist);
        expect(widget.platform, Platform.steam);
      });

      // The captured write is the personalization.md completionist contract: a
      // non-null Steam platform and a bare envelope (no selection
      // sub-object).
      expect(source.lastInsert!['type'], 'completionist');
      expect(source.lastInsert!['platform'], 'steam');
      expect(source.lastInsert!['position'], 4);
      expect(source.lastInsert!['is_enabled'], true);
      final settings = source.lastInsert!['settings'] as Map<String, dynamic>;
      expect(settings['schema_version'], kProfileWidgetSettingsVersion);
      // Size-only: no showcase/collection/completionist sub-object is written.
      expect(settings.containsKey('showcase'), isFalse);
      expect(settings.containsKey('collection'), isFalse);
      expect(settings.containsKey('completionist'), isFalse);
    });

    test('a 23xxx rejection → Left(InputFailure), not reported', () async {
      final source = _FakeDataSource(
        onInsert: (_) async =>
            throw PostgrestException(message: 'cap exceeded', code: '23514'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
      ).addCompletionistWidget(platform: Platform.steam, position: 0);

      result.fold((f) {
        expect(f, isA<InputFailure>());
        expect(f.isExpected, isTrue);
      }, (_) => fail('want Left'));
      expect(reporter.reported, isEmpty);
    });
  });

  group('addPassportWidget', () {
    test('writes type passport, a null platform, and a size-only '
        'envelope', () async {
      final source = _FakeDataSource(
        onInsert: (row) async => _dto({
          'id': 'pp',
          'platform': null,
          'type': 'passport',
          'position': 4,
          'is_enabled': true,
          'settings': {
            'schema_version': kProfileWidgetSettingsVersion,
            'size': 'wide',
          },
        }),
      );
      final result = await _repo(
        source,
        _RecordingReporter(),
      ).addPassportWidget(position: 4);

      result.fold((f) => fail('want Right, got $f'), (widget) {
        expect(widget.id, 'pp');
        expect(widget.kind, ProfileWidgetKind.passport);
        expect(widget.platform, isNull);
      });

      // The captured write is the personalization.md passport contract: a null
      // platform (binding) and a bare envelope (no selection sub-object).
      expect(source.lastInsert!['type'], 'passport');
      expect(source.lastInsert!['platform'], isNull);
      expect(source.lastInsert!['position'], 4);
      expect(source.lastInsert!['is_enabled'], true);
      final settings = source.lastInsert!['settings'] as Map<String, dynamic>;
      expect(settings['schema_version'], kProfileWidgetSettingsVersion);
      // Size-only: no selection sub-object is written.
      expect(settings.containsKey('showcase'), isFalse);
      expect(settings.containsKey('collection'), isFalse);
      expect(settings.containsKey('passport'), isFalse);
    });

    test('a 23xxx rejection → Left(InputFailure), not reported', () async {
      final source = _FakeDataSource(
        onInsert: (_) async =>
            throw PostgrestException(message: 'cap exceeded', code: '23514'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
      ).addPassportWidget(position: 0);

      result.fold((f) {
        expect(f, isA<InputFailure>());
        expect(f.isExpected, isTrue);
      }, (_) => fail('want Left'));
      expect(reporter.reported, isEmpty);
    });
  });

  group('addArtWidget', () {
    test('the normal add writes type art, a null platform, and a size-only '
        'envelope (no source: the render resolves the picture)', () async {
      final source = _FakeDataSource(
        onInsert: (row) async => _dto({
          'id': 'ar',
          'platform': null,
          'type': 'art',
          'position': 2,
          'is_enabled': true,
          'settings': {
            'schema_version': kProfileWidgetSettingsVersion,
            'size': 'wide',
          },
        }),
      );
      final result = await _repo(
        source,
        _RecordingReporter(),
      ).addArtWidget(position: 2);

      result.fold((f) => fail('want Right, got $f'), (widget) {
        expect(widget.kind, ProfileWidgetKind.art);
        expect(widget.platform, isNull);
        expect(widget.artSelection, ArtSelection.empty);
      });

      expect(source.lastInsert!['type'], 'art');
      expect(source.lastInsert!['platform'], isNull);
      final settings = source.lastInsert!['settings'] as Map<String, dynamic>;
      // Unpointed is the wire default: no art sub-object at all.
      expect(settings.containsKey('art'), isFalse);
    });

    test('a pinned source rides in the envelope (the picker seam)', () async {
      final source = _FakeDataSource(
        onInsert: (row) async => _dto({
          'id': 'ar',
          'platform': null,
          'type': 'art',
          'position': 2,
          'is_enabled': true,
          'settings': {
            'schema_version': kProfileWidgetSettingsVersion,
            'size': 'wide',
            'art': {'source': 'league_of_legends'},
          },
        }),
      );
      final result = await _repo(
        source,
        _RecordingReporter(),
      ).addArtWidget(source: Platform.leagueOfLegends, position: 2);

      result.fold((f) => fail('want Right, got $f'), (widget) {
        expect(widget.id, 'ar');
        expect(widget.kind, ProfileWidgetKind.art);
        expect(widget.platform, isNull);
        expect(widget.artSelection.source, Platform.leagueOfLegends);
      });

      expect(source.lastInsert!['type'], 'art');
      // The row stays unbound: the picture's source is a choice in the
      // envelope, not an account the card reads.
      expect(source.lastInsert!['platform'], isNull);
      expect(source.lastInsert!['position'], 2);
      expect(source.lastInsert!['is_enabled'], true);
      final settings = source.lastInsert!['settings'] as Map<String, dynamic>;
      expect(settings['schema_version'], kProfileWidgetSettingsVersion);
      expect((settings['art']! as Map)['source'], 'league_of_legends');
    });

    test('a 23xxx rejection → Left(InputFailure), not reported', () async {
      final source = _FakeDataSource(
        onInsert: (_) async =>
            throw PostgrestException(message: 'cap exceeded', code: '23514'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
      ).addArtWidget(source: Platform.steam, position: 0);

      result.fold((f) {
        expect(f, isA<InputFailure>());
        expect(f.isExpected, isTrue);
      }, (_) => fail('want Left'));
      expect(reporter.reported, isEmpty);
    });
  });

  group('addRankWidget', () {
    test('writes type rank, a non-null platform, and a size-only '
        'envelope', () async {
      final source = _FakeDataSource(
        onInsert: (row) async => _dto({
          'id': 'rk',
          'platform': 'league_of_legends',
          'type': 'rank',
          'position': 4,
          'is_enabled': true,
          'settings': {
            'schema_version': kProfileWidgetSettingsVersion,
            'size': 'small',
          },
        }),
      );
      final result = await _repo(
        source,
        _RecordingReporter(),
      ).addRankWidget(platform: Platform.leagueOfLegends, position: 4);

      result.fold((f) => fail('want Right, got $f'), (widget) {
        expect(widget.id, 'rk');
        expect(widget.kind, ProfileWidgetKind.rank);
        expect(widget.platform, Platform.leagueOfLegends);
      });

      // The captured write is the personalization.md rank contract: a non-null
      // platform and a bare envelope (no selection sub-object).
      expect(source.lastInsert!['type'], 'rank');
      expect(source.lastInsert!['platform'], 'league_of_legends');
      expect(source.lastInsert!['position'], 4);
      expect(source.lastInsert!['is_enabled'], true);
      final settings = source.lastInsert!['settings'] as Map<String, dynamic>;
      expect(settings['schema_version'], kProfileWidgetSettingsVersion);
      // Size-only: no selection sub-object is written.
      expect(settings.containsKey('showcase'), isFalse);
      expect(settings.containsKey('collection'), isFalse);
      expect(settings.containsKey('rank'), isFalse);
    });

    test('a 23xxx rejection → Left(InputFailure), not reported', () async {
      final source = _FakeDataSource(
        onInsert: (_) async =>
            throw PostgrestException(message: 'cap exceeded', code: '23514'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
      ).addRankWidget(platform: Platform.leagueOfLegends, position: 0);

      result.fold((f) {
        expect(f, isA<InputFailure>());
        expect(f.isExpected, isTrue);
      }, (_) => fail('want Left'));
      expect(reporter.reported, isEmpty);
    });
  });

  group('addMainWidget', () {
    test('writes type main, a non-null platform, and a size-only '
        'envelope', () async {
      final source = _FakeDataSource(
        onInsert: (row) async => _dto({
          'id': 'mn',
          'platform': 'steam',
          'type': 'main',
          'position': 4,
          'is_enabled': true,
          'settings': {
            'schema_version': kProfileWidgetSettingsVersion,
            'size': 'wide',
          },
        }),
      );
      final result = await _repo(
        source,
        _RecordingReporter(),
      ).addMainWidget(platform: Platform.steam, position: 4);

      result.fold((f) => fail('want Right, got $f'), (widget) {
        expect(widget.id, 'mn');
        expect(widget.kind, ProfileWidgetKind.main);
        expect(widget.platform, Platform.steam);
      });

      // The captured write is the personalization.md main contract: a non-null
      // platform and a bare envelope (no selection sub-object).
      expect(source.lastInsert!['type'], 'main');
      expect(source.lastInsert!['platform'], 'steam');
      expect(source.lastInsert!['position'], 4);
      expect(source.lastInsert!['is_enabled'], true);
      final settings = source.lastInsert!['settings'] as Map<String, dynamic>;
      expect(settings['schema_version'], kProfileWidgetSettingsVersion);
      // Size-only: no selection sub-object is written.
      expect(settings.containsKey('showcase'), isFalse);
      expect(settings.containsKey('collection'), isFalse);
      expect(settings.containsKey('main'), isFalse);
    });

    test('a 23xxx rejection → Left(InputFailure), not reported', () async {
      final source = _FakeDataSource(
        onInsert: (_) async =>
            throw PostgrestException(message: 'cap exceeded', code: '23514'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
      ).addMainWidget(platform: Platform.steam, position: 0);

      result.fold((f) {
        expect(f, isA<InputFailure>());
        expect(f.isExpected, isTrue);
      }, (_) => fail('want Left'));
      expect(reporter.reported, isEmpty);
    });
  });

  group('addRecentWidget', () {
    test('writes type recent, a non-null platform, and a bare '
        'envelope', () async {
      final source = _FakeDataSource(
        onInsert: (row) async => _dto({
          'id': 'rc',
          'platform': 'steam',
          'type': 'recent',
          'position': 4,
          'is_enabled': true,
          'settings': {'schema_version': kProfileWidgetSettingsVersion},
        }),
      );
      final result = await _repo(
        source,
        _RecordingReporter(),
      ).addRecentWidget(platform: Platform.steam, position: 4);

      result.fold((f) => fail('want Right, got $f'), (widget) {
        expect(widget.id, 'rc');
        expect(widget.kind, ProfileWidgetKind.recent);
        expect(widget.platform, Platform.steam);
      });

      // The captured write is the brief's recent contract: a non-null platform
      // and a bare envelope (no selection sub-object).
      expect(source.lastInsert!['type'], 'recent');
      expect(source.lastInsert!['platform'], 'steam');
      expect(source.lastInsert!['position'], 4);
      expect(source.lastInsert!['is_enabled'], true);
      final settings = source.lastInsert!['settings'] as Map<String, dynamic>;
      expect(settings['schema_version'], kProfileWidgetSettingsVersion);
      expect(settings.keys, ['schema_version']);
    });

    test('a 23xxx rejection → Left(InputFailure), not reported', () async {
      final source = _FakeDataSource(
        onInsert: (_) async =>
            throw PostgrestException(message: 'cap exceeded', code: '23514'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
      ).addRecentWidget(platform: Platform.steam, position: 0);

      result.fold((f) {
        expect(f, isA<InputFailure>());
        expect(f.isExpected, isTrue);
      }, (_) => fail('want Left'));
      expect(reporter.reported, isEmpty);
    });
  });

  group('addPersonalBestWidget', () {
    test('writes type personal_best, a non-null platform, is_enabled and a '
        'bare v1 envelope', () async {
      final source = _FakeDataSource(
        onInsert: (row) async => _dto({
          'id': 'pb',
          'platform': 'chess',
          'type': 'personal_best',
          'position': 8,
          'is_enabled': true,
          'settings': {'schema_version': kProfileWidgetSettingsVersion},
        }),
      );
      final result = await _repo(
        source,
        _RecordingReporter(),
      ).addPersonalBestWidget(platform: Platform.chess, position: 8);

      result.fold((f) => fail('want Right, got $f'), (widget) {
        expect(widget.id, 'pb');
        expect(widget.kind, ProfileWidgetKind.personalBest);
        expect(widget.platform, Platform.chess);
      });

      // The captured write is the brief's contract: a non-null platform and a
      // bare envelope (no selection sub-object).
      expect(source.lastInsert!['type'], 'personal_best');
      expect(source.lastInsert!['platform'], 'chess');
      expect(source.lastInsert!['position'], 8);
      expect(source.lastInsert!['is_enabled'], true);
      final settings = source.lastInsert!['settings'] as Map<String, dynamic>;
      expect(settings['schema_version'], kProfileWidgetSettingsVersion);
      expect(settings.keys, ['schema_version']);
    });

    test('an unauthenticated add → Left(AuthFailure)', () async {
      final result = await _repo(
        _FakeDataSource(),
        _RecordingReporter(),
        userId: null,
      ).addPersonalBestWidget(platform: Platform.chess, position: 0);

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('want Left'),
      );
    });
  });

  group('addRarestAchievementWidget', () {
    test('writes type rarest_achievement, a non-null platform, is_enabled and '
        'a bare v1 envelope', () async {
      final source = _FakeDataSource(
        onInsert: (row) async => _dto({
          'id': 'ra',
          'platform': 'steam',
          'type': 'rarest_achievement',
          'position': 6,
          'is_enabled': true,
          'settings': {'schema_version': kProfileWidgetSettingsVersion},
        }),
      );
      final result = await _repo(
        source,
        _RecordingReporter(),
      ).addRarestAchievementWidget(platform: Platform.steam, position: 6);

      result.fold((f) => fail('want Right, got $f'), (widget) {
        expect(widget.id, 'ra');
        expect(widget.kind, ProfileWidgetKind.rarestAchievement);
        expect(widget.platform, Platform.steam);
      });

      // The captured write is the brief's contract: a non-null platform and a
      // bare envelope (no selection sub-object).
      expect(source.lastInsert!['type'], 'rarest_achievement');
      expect(source.lastInsert!['platform'], 'steam');
      expect(source.lastInsert!['position'], 6);
      expect(source.lastInsert!['is_enabled'], true);
      final settings = source.lastInsert!['settings'] as Map<String, dynamic>;
      expect(settings['schema_version'], kProfileWidgetSettingsVersion);
      expect(settings.keys, ['schema_version']);
    });

    test('an unauthenticated add → Left(AuthFailure)', () async {
      final result = await _repo(
        _FakeDataSource(),
        _RecordingReporter(),
        userId: null,
      ).addRarestAchievementWidget(platform: Platform.steam, position: 0);

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('want Left'),
      );
    });
  });

  group('mutations write the expected values', () {
    test(
      'setShowcaseSelection rewrites the envelope preserving the selection',
      () async {
        final source = _FakeDataSource();
        await _repo(
          source,
          _RecordingReporter(),
        ).setShowcaseSelection('sc', const ShowcaseSelection(gameRef: '730'));

        // The write is the whole envelope: the game selection must survive it
        // or the card resolves as unavailable.
        final settings =
            source.lastUpdate!.values['settings'] as Map<String, dynamic>;
        expect(settings['schema_version'], kProfileWidgetSettingsVersion);
        final showcase = settings['showcase'] as Map<String, dynamic>;
        expect(showcase['game'], '730');
        expect(showcase['hero'], 'hours');
      },
    );
  });
}
