import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/profile/data/profile_widget_dto.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row({
  String id = 'w-1',
  String? platform = 'steam',
  String type = 'platform',
  int position = 0,
  bool isEnabled = true,
  Object? size = 'small',
  int? schemaVersion = kProfileWidgetSettingsVersion,
  bool includeSettings = true,
}) {
  final settings = <String, dynamic>{};
  if (schemaVersion != null) settings['schema_version'] = schemaVersion;
  if (size != null) settings['size'] = size;
  return {
    'id': id,
    'platform': platform,
    'type': type,
    'position': position,
    'is_enabled': isEnabled,
    if (includeSettings) 'settings': settings,
  };
}

void main() {
  group('profileWidgetFromDto — v1 envelope', () {
    test('maps a platform widget with a size token', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(size: 'wide', position: 3)),
      );

      expect(widget, isNotNull);
      expect(widget!.kind, ProfileWidgetKind.platform);
      expect(widget.platform, Platform.steam);
      expect(widget.size, ProfileWidgetSize.wide);
      expect(widget.position, 3);
      expect(widget.isEnabled, isTrue);
    });

    test('round-trips the three size tokens', () {
      const cases = {
        'small': ProfileWidgetSize.small,
        'wide': ProfileWidgetSize.wide,
        'large': ProfileWidgetSize.large,
      };
      for (final entry in cases.entries) {
        final widget = profileWidgetFromDto(
          ProfileWidgetDto.fromJson(_row(size: entry.key)),
        );
        expect(widget!.size, entry.value, reason: entry.key);
      }
    });

    test('unknown size token → small', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(size: 'gigantic')),
      );
      expect(widget!.size, ProfileWidgetSize.small);
    });

    test('absent size key → small', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(size: null)),
      );
      expect(widget!.size, ProfileWidgetSize.small);
    });

    test('absent settings entirely → small', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(includeSettings: false)),
      );
      expect(widget, isNotNull);
      expect(widget!.size, ProfileWidgetSize.small);
    });
  });

  group('profileWidgetFromDto — soft resolution', () {
    test('unknown type token → null (omit)', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(type: 'data_menu')),
      );
      expect(widget, isNull);
    });

    test('reserved (unwired) kind tokens all degrade to null (omit)', () {
      // The reserved kinds are named in the wire taxonomy but not yet wired on
      // read; an older client must omit a row a newer client writes, never
      // crash. Mirrors profileWidgetKindToWire's reserved branches.
      for (final token in const ['data_menu', 'template', 'composed']) {
        final widget = profileWidgetFromDto(
          ProfileWidgetDto.fromJson(_row(type: token)),
        );
        expect(widget, isNull, reason: token);
      }
    });

    test('schema_version != 1 → null (omit)', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(schemaVersion: 2)),
      );
      expect(widget, isNull);
    });

    test('unknown platform token on a platform kind → null (omit)', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(platform: 'not_a_platform')),
      );
      expect(widget, isNull);
    });

    test('null platform on a platform kind → null (omit)', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(platform: null)),
      );
      expect(widget, isNull);
    });
  });

  group('serialization helpers', () {
    test('profileWidgetSizeToWire round-trips the size tokens', () {
      expect(profileWidgetSizeToWire(ProfileWidgetSize.small), 'small');
      expect(profileWidgetSizeToWire(ProfileWidgetSize.wide), 'wide');
      expect(profileWidgetSizeToWire(ProfileWidgetSize.large), 'large');
    });

    test('profileWidgetKindToWire maps every kind to its wire token', () {
      expect(profileWidgetKindToWire(ProfileWidgetKind.platform), 'platform');
      expect(profileWidgetKindToWire(ProfileWidgetKind.dataMenu), 'data_menu');
      expect(profileWidgetKindToWire(ProfileWidgetKind.template), 'template');
      expect(profileWidgetKindToWire(ProfileWidgetKind.composed), 'composed');
    });
  });
}
