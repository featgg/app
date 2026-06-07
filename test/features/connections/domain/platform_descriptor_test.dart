import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/platform_descriptor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('platformDescriptors', () {
    test('registers Steam and Minecraft (Hypixel)', () {
      expect(platformDescriptors.containsKey(Platform.steam), isTrue);
      expect(
        platformDescriptors.containsKey(Platform.minecraftHypixel),
        isTrue,
      );
    });

    test('Minecraft descriptor carries the documented wire configuration', () {
      final descriptor = platformDescriptors[Platform.minecraftHypixel]!;
      expect(descriptor.platform, Platform.minecraftHypixel);
      expect(descriptor.displayName, 'Minecraft (Hypixel)');
      expect(descriptor.wireValue, 'minecraft_hypixel');
      expect(descriptor.syncFunctionName, 'sync-minecraft-hypixel');
    });

    test('registers RetroAchievements', () {
      expect(
        platformDescriptors.containsKey(Platform.retroachievements),
        isTrue,
      );
    });

    test(
      'RetroAchievements descriptor carries the documented wire configuration',
      () {
        final descriptor = platformDescriptors[Platform.retroachievements]!;
        expect(descriptor.platform, Platform.retroachievements);
        expect(descriptor.displayName, 'RetroAchievements');
        expect(descriptor.wireValue, 'retroachievements');
        expect(descriptor.syncFunctionName, 'sync-retroachievements');
      },
    );

    test('every descriptor is keyed by its own platform', () {
      for (final entry in platformDescriptors.entries) {
        expect(entry.value.platform, entry.key);
      }
    });
  });
}
