import 'dart:async';
import 'dart:io';

import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/observability/observability.dart';
import 'package:featgg/src/features/connections/data/cards_data_source.dart';
import 'package:featgg/src/features/connections/data/cards_repository_impl.dart';
import 'package:featgg/src/features/connections/data/game_card_dto.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
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

final class _FakeCardsDataSource implements CardsDataSource {
  _FakeCardsDataSource(this._onFetch);

  final Future<GameCardDto?> Function(String userId, String platformWireValue)
  _onFetch;

  @override
  Future<GameCardDto?> fetchCard(String userId, String platformWireValue) =>
      _onFetch(userId, platformWireValue);
}

CardsRepositoryImpl _repo(
  CardsDataSource source,
  _RecordingReporter reporter, {
  String? userId = 'user-1',
}) => CardsRepositoryImpl(source, () => userId, reporter);

const _steamWidgetData = <String, dynamic>{
  'schema_version': 1,
  'platform': 'steam',
  'title': 'TestUser',
  'subtitle': null,
  'icon_image': 'https://cdn.example.com/icon.jpg',
  'hero_image': 'https://cdn.example.com/hero.jpg',
  'profile_url': 'https://steamcommunity.com/id/test/',
  'stats': [
    {'key': 'hours_played', 'value': 1240, 'unit': 'hours'},
    {'key': 'games_owned', 'value': 312, 'unit': 'count'},
  ],
  'last_updated': '2026-06-03T12:00:00Z',
  'data': {'library_showcase': [], 'recent_games': []},
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('CardsRepositoryImpl.fetchMyCard', () {
    test('returns Left(AuthFailure) when no user session', () async {
      final source = _FakeCardsDataSource((_, _) async => null);
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
        userId: null,
      ).fetchMyCard(Platform.steam);

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, isEmpty);
    });

    test('maybeSingle null → Right(null)', () async {
      final source = _FakeCardsDataSource((_, _) async => null);
      final reporter = _RecordingReporter();
      final result = await _repo(source, reporter).fetchMyCard(Platform.steam);

      result.fold(
        (f) => fail('want Right, got $f'),
        (card) => expect(card, isNull),
      );
      expect(reporter.reported, isEmpty);
    });

    test('widget_data row → Right(GameCard) with SteamCardData', () async {
      final source = _FakeCardsDataSource(
        (_, _) async =>
            GameCardDto.fromJson(Map<String, dynamic>.from(_steamWidgetData)),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(source, reporter).fetchMyCard(Platform.steam);

      result.fold((f) => fail('want Right, got $f'), (card) {
        expect(card, isNotNull);
        expect(card!.platform, Platform.steam);
        expect(card.title, 'TestUser');
        expect(card.stats, hasLength(2));
        expect(card.data, isA<SteamCardData>());
      });
    });

    test('PostgrestException 401 → Left(AuthFailure), not reported', () async {
      final source = _FakeCardsDataSource(
        (_, _) async =>
            throw PostgrestException(message: 'unauthorized', code: '401'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(source, reporter).fetchMyCard(Platform.steam);

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, isEmpty);
    });

    test('SocketException → Left(NetworkFailure), not reported', () async {
      final source = _FakeCardsDataSource(
        (_, _) async => throw const SocketException('no route'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(source, reporter).fetchMyCard(Platform.steam);

      result.fold(
        (f) => expect(f, isA<NetworkFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, isEmpty);
    });

    test('TimeoutException → Left(NetworkFailure), not reported', () async {
      final source = _FakeCardsDataSource(
        (_, _) async => throw TimeoutException('timed out'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(source, reporter).fetchMyCard(Platform.steam);

      result.fold(
        (f) => expect(f, isA<NetworkFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, isEmpty);
    });

    test('parse fault → Left(UnexpectedFailure), reported', () async {
      final source = _FakeCardsDataSource(
        // Simulates what the real data source throws when widget_data is
        // malformed (fromJson fails at the edge).
        (_, _) async => throw const FormatException('bad widget_data'),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(source, reporter).fetchMyCard(Platform.steam);

      result.fold(
        (f) => expect(f, isA<UnexpectedFailure>()),
        (_) => fail('want Left'),
      );
      expect(reporter.reported, hasLength(1));
    });

    test(
      'data source returns null for non-v1 schema_version → Right(null)',
      () async {
        // Models the data source returning null when schema_version != 1
        // (the version gate in SupabaseCardsDataSource). The repository must
        // treat null as card-unavailable, not an error.
        final source = _FakeCardsDataSource((_, _) async => null);
        final reporter = _RecordingReporter();
        final result = await _repo(
          source,
          reporter,
        ).fetchMyCard(Platform.steam);

        result.fold(
          (f) => fail('want Right(null), got $f'),
          (card) => expect(card, isNull),
        );
        expect(reporter.reported, isEmpty);
      },
    );
  });

  group('CardsRepositoryImpl.fetchPublicCard', () {
    test('maps a public row to a GameCard', () async {
      final source = _FakeCardsDataSource(
        (_, _) async =>
            GameCardDto.fromJson(Map<String, dynamic>.from(_steamWidgetData)),
      );
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
      ).fetchPublicCard('other-user', Platform.steam);

      result.fold((f) => fail('want Right, got $f'), (card) {
        expect(card, isNotNull);
        expect(card!.platform, Platform.steam);
        expect(card.title, 'TestUser');
        expect(card.stats, hasLength(2));
        expect(card.data, isA<SteamCardData>());
      });
      expect(reporter.reported, isEmpty);
    });

    test('returns Right(null) when no row', () async {
      final source = _FakeCardsDataSource((_, _) async => null);
      final reporter = _RecordingReporter();
      final result = await _repo(
        source,
        reporter,
      ).fetchPublicCard('other-user', Platform.steam);

      result.fold(
        (f) => fail('want Right(null), got $f'),
        (card) => expect(card, isNull),
      );
      expect(reporter.reported, isEmpty);
    });
  });
}
