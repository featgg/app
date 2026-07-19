import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/profile/domain/profile_archetype.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:flutter_test/flutter_test.dart';

ProfileWidget _widget(ProfileWidgetKind kind) => ProfileWidget(
  id: 'w',
  kind: kind,
  platform: Platform.steam,
  position: 0,
  isEnabled: true,
  size: ProfileWidgetSize.small,
);

void main() {
  group('archetypeForWidget (spec §7 legacy mapping)', () {
    test('passport → identity, showcase → milestone, platform → platform', () {
      expect(
        archetypeForWidget(_widget(ProfileWidgetKind.passport)),
        ProfileArchetype.identity,
      );
      expect(
        archetypeForWidget(_widget(ProfileWidgetKind.showcase)),
        ProfileArchetype.milestone,
      );
      expect(
        archetypeForWidget(_widget(ProfileWidgetKind.platform)),
        ProfileArchetype.platform,
      );
    });

    test('every other kind falls through to fallback', () {
      for (final kind in const [
        ProfileWidgetKind.collection,
        ProfileWidgetKind.gameCollector,
        ProfileWidgetKind.completionist,
        ProfileWidgetKind.template,
        ProfileWidgetKind.composed,
        ProfileWidgetKind.dataMenu,
      ]) {
        expect(
          archetypeForWidget(_widget(kind)),
          ProfileArchetype.fallback,
          reason: '$kind should map to the fallback archetype',
        );
      }
    });
  });

  group('supportedSizes (spec §5)', () {
    test('identity is full-only', () {
      expect(supportedSizes(ProfileArchetype.identity), {ProfileCardSize.full});
    });

    test('platform, milestone, and fallback support both sizes', () {
      for (final archetype in const [
        ProfileArchetype.platform,
        ProfileArchetype.milestone,
        ProfileArchetype.fallback,
      ]) {
        expect(
          supportedSizes(archetype),
          {ProfileCardSize.full, ProfileCardSize.half},
          reason: '$archetype should support full and half',
        );
      }
    });
  });
}
