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
}
