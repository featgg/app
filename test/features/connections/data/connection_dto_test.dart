import 'package:featgg/src/features/connections/data/connection_dto.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('connectionFromDtoOrNull', () {
    test('maps a full linked_accounts row to a Connection', () {
      final dto = ConnectionDto.fromJson({
        'platform': 'steam',
        'status': 'active',
        'created_at': '2026-01-01T00:00:00Z',
        'last_sync_at': '2026-06-01T12:00:00Z',
        'remote_id': '76561198000000000',
      });

      final conn = connectionFromDtoOrNull(dto)!;

      expect(conn.platform, Platform.steam);
      expect(conn.status, ConnectionStatus.active);
      expect(conn.createdAt, DateTime.parse('2026-01-01T00:00:00Z'));
      expect(conn.lastSyncAt, DateTime.parse('2026-06-01T12:00:00Z'));
      expect(conn.remoteId, '76561198000000000');
    });

    test('maps null last_sync_at correctly', () {
      final dto = ConnectionDto.fromJson({
        'platform': 'steam',
        'status': 'error',
        'created_at': '2026-01-01T00:00:00Z',
        'last_sync_at': null,
        'remote_id': null,
      });

      final conn = connectionFromDtoOrNull(dto)!;

      expect(conn.status, ConnectionStatus.error);
      expect(conn.lastSyncAt, isNull);
      expect(conn.remoteId, isNull);
    });

    test('unknown status token throws FormatException', () {
      final dto = ConnectionDto.fromJson({
        'platform': 'steam',
        'status': 'pending',
        'created_at': '2026-01-01T00:00:00Z',
      });

      expect(() => connectionFromDtoOrNull(dto), throwsFormatException);
    });

    test('unknown platform token yields null (dropped)', () {
      final dto = ConnectionDto.fromJson({
        'platform': 'unknown_platform',
        'status': 'active',
        'created_at': '2026-01-01T00:00:00Z',
      });

      expect(connectionFromDtoOrNull(dto), isNull);
    });

    test('maps a metadata row to Connection.metadata', () {
      final dto = ConnectionDto.fromJson({
        'platform': 'league_of_legends',
        'status': 'active',
        'created_at': '2026-01-01T00:00:00Z',
        'metadata': {
          'game_name': 'TestPlayer',
          'tag_line': 'NA1',
          'region': 'na1',
        },
      });

      final conn = connectionFromDtoOrNull(dto)!;

      expect(conn.platform, Platform.leagueOfLegends);
      expect(conn.metadata, {
        'game_name': 'TestPlayer',
        'tag_line': 'NA1',
        'region': 'na1',
      });
      expect(conn.remoteId, isNull);
    });

    test('maps all seven platform wire values', () {
      const platforms = {
        'steam': Platform.steam,
        'league_of_legends': Platform.leagueOfLegends,
        'wow_retail': Platform.wowRetail,
        'minecraft_hypixel': Platform.minecraftHypixel,
        'chess': Platform.chess,
        'retroachievements': Platform.retroachievements,
        'gw2': Platform.gw2,
      };

      for (final entry in platforms.entries) {
        final dto = ConnectionDto.fromJson({
          'platform': entry.key,
          'status': 'active',
          'created_at': '2026-01-01T00:00:00Z',
        });
        expect(connectionFromDtoOrNull(dto)!.platform, entry.value);
      }
    });
  });
}
