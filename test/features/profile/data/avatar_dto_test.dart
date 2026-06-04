import 'package:featgg/src/features/profile/data/avatar_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AvatarUploadDto.fromJson', () {
    test('maps avatar_url from the success envelope', () {
      const json = {'avatar_url': 'https://example.com/avatar.jpg'};
      final dto = AvatarUploadDto.fromJson(json);
      expect(dto.avatarUrl, 'https://example.com/avatar.jpg');
    });
  });

  group('AvatarModerationDetailsDto.fromJson', () {
    test('maps categories when present', () {
      const json = {
        'categories': ['nudity', 'violence'],
      };
      final dto = AvatarModerationDetailsDto.fromJson(json);
      expect(dto.categories, ['nudity', 'violence']);
    });

    test('defaults to empty list when categories key is absent', () {
      final dto = AvatarModerationDetailsDto.fromJson(const {});
      expect(dto.categories, isEmpty);
    });
  });
}
