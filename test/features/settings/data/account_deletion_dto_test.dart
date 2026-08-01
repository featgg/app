import 'package:featgg/src/features/settings/data/account_deletion_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('account-deletion DTOs', () {
    test('DeletionRequestDto.fromJson parses {success, otp_sent}', () {
      final dto = DeletionRequestDto.fromJson({
        'success': true,
        'otp_sent': true,
      });
      expect(dto.success, isTrue);
      expect(dto.otpSent, isTrue);
    });

    test(
      'DeletionConfirmDto.fromJson parses {success, deletion_scheduled_at}',
      () {
        final dto = DeletionConfirmDto.fromJson({
          'success': true,
          'deletion_scheduled_at': '2026-06-18T00:00:00Z',
        });
        expect(dto.success, isTrue);
        expect(dto.deletionScheduledAt, '2026-06-18T00:00:00Z');
      },
    );

    test('DeletionCancelDto.fromJson parses {success, cancelled}', () {
      final dto = DeletionCancelDto.fromJson({
        'success': true,
        'cancelled': true,
      });
      expect(dto.success, isTrue);
      expect(dto.cancelled, isTrue);
    });
  });

  group('DeletionStatusDto.fromPayload', () {
    test('null reads as no deletion pending', () {
      expect(DeletionStatusDto.fromPayload(null).requestedAt, isNull);
    });

    test('an ISO-8601 string carries the timestamp', () {
      expect(
        DeletionStatusDto.fromPayload('2026-06-12T10:00:00Z').requestedAt,
        '2026-06-12T10:00:00Z',
      );
    });

    test('throws on a shape that is neither a string nor null', () {
      // Hiding a pending deletion from its owner is worse than an error, so an
      // unexpected payload must be a fault — never a silent "not pending".
      for (final payload in <Object>[
        <String, dynamic>{'requested_at': '2026-06-12T10:00:00Z'},
        <dynamic>['2026-06-12T10:00:00Z'],
        42,
        true,
      ]) {
        expect(
          () => DeletionStatusDto.fromPayload(payload),
          throwsA(isA<FormatException>()),
          reason: '${payload.runtimeType} must not degrade to "not pending"',
        );
      }
    });
  });
}
