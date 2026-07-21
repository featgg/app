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

    test('rank → rank, main → main', () {
      expect(
        archetypeForWidget(_widget(ProfileWidgetKind.rank)),
        ProfileArchetype.rank,
      );
      expect(
        archetypeForWidget(_widget(ProfileWidgetKind.main)),
        ProfileArchetype.main,
      );
    });

    test('rank and main are NOT the fallback archetype', () {
      // A regression guard: were the registry mapping dropped, both would fall
      // through to fallback and render the generic card instead of their anatomy.
      expect(
        archetypeForWidget(_widget(ProfileWidgetKind.rank)),
        isNot(ProfileArchetype.fallback),
      );
      expect(
        archetypeForWidget(_widget(ProfileWidgetKind.main)),
        isNot(ProfileArchetype.fallback),
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

    test(
      'platform, milestone, rank, main, and fallback support both sizes',
      () {
        for (final archetype in const [
          ProfileArchetype.platform,
          ProfileArchetype.milestone,
          ProfileArchetype.rank,
          ProfileArchetype.main,
          ProfileArchetype.fallback,
        ]) {
          expect(
            supportedSizes(archetype),
            {ProfileCardSize.full, ProfileCardSize.half},
            reason: '$archetype should support full and half',
          );
        }
      },
    );

    test('rank supports both full and half (not half-only)', () {
      expect(supportedSizes(ProfileArchetype.rank), {
        ProfileCardSize.full,
        ProfileCardSize.half,
      });
    });
  });
}
