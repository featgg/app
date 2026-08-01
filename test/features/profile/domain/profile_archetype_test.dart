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

    test('recent → the recent archetype', () {
      expect(
        archetypeForWidget(_widget(ProfileWidgetKind.recent)),
        ProfileArchetype.recent,
      );
    });

    test('rarest_achievement maps to its own archetype', () {
      expect(
        archetypeForWidget(_widget(ProfileWidgetKind.rarestAchievement)),
        ProfileArchetype.rarestAchievement,
      );
    });

    test('collection and game_collector → collection, completionist → '
        'achievement grid', () {
      expect(
        archetypeForWidget(_widget(ProfileWidgetKind.collection)),
        ProfileArchetype.collection,
      );
      expect(
        archetypeForWidget(_widget(ProfileWidgetKind.gameCollector)),
        ProfileArchetype.collection,
      );
      expect(
        archetypeForWidget(_widget(ProfileWidgetKind.completionist)),
        ProfileArchetype.achievementGrid,
      );
    });

    test('rank, main, collection, and achievementGrid are NOT the fallback '
        'archetype', () {
      // A regression guard: were the registry mapping dropped, each would fall
      // through to fallback and render the generic card instead of its anatomy.
      for (final kind in const [
        ProfileWidgetKind.rank,
        ProfileWidgetKind.main,
        ProfileWidgetKind.collection,
        ProfileWidgetKind.gameCollector,
        ProfileWidgetKind.completionist,
      ]) {
        expect(
          () => archetypeForWidget(_widget(kind)),
          returnsNormally,
          reason: '$kind should map to a designed archetype',
        );
      }
    });
  });

  group('supportedSizes (spec §5)', () {
    test('identity is full-only', () {
      expect(supportedSizes(ProfileArchetype.identity), {ProfileCardSize.full});
    });

    test('platform, milestone, rank, and main support both sizes', () {
      for (final archetype in const [
        ProfileArchetype.platform,
        ProfileArchetype.milestone,
        ProfileArchetype.rank,
        ProfileArchetype.main,
      ]) {
        expect(
          supportedSizes(archetype),
          {ProfileCardSize.full, ProfileCardSize.half},
          reason: '$archetype should support full and half',
        );
      }
    });

    test('recent supports full and half', () {
      // One datum with its own subject is legal as a half; the full variant is
      // where the all-time figure earns its width.
      expect(supportedSizes(ProfileArchetype.recent), {
        ProfileCardSize.full,
        ProfileCardSize.half,
      });
    });

    test('rarest achievement supports full and half', () {
      // One subject line, one context line and one figure: the shape a half
      // already carries, while the full variant gives a long achievement name
      // the width it usually needs.
      expect(supportedSizes(ProfileArchetype.rarestAchievement), {
        ProfileCardSize.full,
        ProfileCardSize.half,
      });
    });

    test('rank supports both full and half (not half-only)', () {
      expect(supportedSizes(ProfileArchetype.rank), {
        ProfileCardSize.full,
        ProfileCardSize.half,
      });
    });

    test('collection and achievementGrid are full-only (spec §7)', () {
      // Full-only drives the editor to offer no half placement / no side-drop.
      expect(supportedSizes(ProfileArchetype.collection), {
        ProfileCardSize.full,
      });
      expect(supportedSizes(ProfileArchetype.achievementGrid), {
        ProfileCardSize.full,
      });
    });
  });

  group('cardFormat', () {
    test('an archetype whose subject has a published art source is bleed', () {
      for (final archetype in const [
        ProfileArchetype.platform,
        ProfileArchetype.milestone,
        ProfileArchetype.main,
        ProfileArchetype.recent,
        // The payload publishes the game's art on the achievement's own block.
        ProfileArchetype.rarestAchievement,
      ]) {
        expect(
          cardFormat(archetype),
          ProfileCardFormat.bleed,
          reason: '$archetype resolves real art for its subject',
        );
      }
    });

    test('an archetype with no art source for its subject is framed', () {
      for (final archetype in const [
        ProfileArchetype.identity,
        ProfileArchetype.rank,
        ProfileArchetype.collection,
        ProfileArchetype.achievementGrid,
      ]) {
        expect(
          cardFormat(archetype),
          ProfileCardFormat.framed,
          reason: '$archetype has no single published subject image',
        );
      }
    });

    test('the format is declared for every archetype', () {
      // A new archetype cannot render without declaring its format here rather
      // than branching inside its card.
      for (final archetype in ProfileArchetype.values) {
        expect(cardFormat(archetype), isA<ProfileCardFormat>());
      }
    });
  });

  group('renderedCardFormat', () {
    test(
      'a bleed archetype degrades to framed when the subject has no art',
      () {
        expect(
          renderedCardFormat(ProfileArchetype.milestone, hasArt: false),
          ProfileCardFormat.framed,
        );
      },
    );

    test('a bleed archetype renders bleed when real art exists', () {
      expect(
        renderedCardFormat(ProfileArchetype.milestone, hasArt: true),
        ProfileCardFormat.bleed,
      );
    });

    test('a framed archetype renders framed even when handed art', () {
      // The registry owns the format, so a mis-wired art url cannot flip a
      // framed card into the bleed chassis.
      expect(
        renderedCardFormat(ProfileArchetype.rank, hasArt: true),
        ProfileCardFormat.framed,
      );
      expect(
        renderedCardFormat(ProfileArchetype.rank, hasArt: false),
        ProfileCardFormat.framed,
      );
    });
  });

  group('rendersPortraitFull', () {
    test('art is the only archetype whose full variant is portrait', () {
      expect(rendersPortraitFull(ProfileArchetype.art), isTrue);
      for (final archetype in ProfileArchetype.values) {
        if (archetype == ProfileArchetype.art) continue;
        expect(rendersPortraitFull(archetype), isFalse, reason: archetype.name);
      }
    });
  });

  group('cardCategory (the question-category model)', () {
    test('every catalog kind lands in its question-category', () {
      expect(
        cardCategory(ProfileWidgetKind.passport),
        ProfileCardCategory.whoIAm,
      );
      expect(
        cardCategory(ProfileWidgetKind.main),
        ProfileCardCategory.whatIPlay,
      );
      expect(
        cardCategory(ProfileWidgetKind.recent),
        ProfileCardCategory.whatIPlay,
      );
      expect(
        cardCategory(ProfileWidgetKind.rank),
        ProfileCardCategory.howGoodIAm,
      );
      expect(
        cardCategory(ProfileWidgetKind.showcase),
        ProfileCardCategory.whatIAchieved,
      );
      expect(
        cardCategory(ProfileWidgetKind.completionist),
        ProfileCardCategory.whatIAchieved,
      );
      expect(
        cardCategory(ProfileWidgetKind.collection),
        ProfileCardCategory.whatIOwn,
      );
      expect(
        cardCategory(ProfileWidgetKind.gameCollector),
        ProfileCardCategory.whatIOwn,
      );
      expect(cardCategory(ProfileWidgetKind.art), ProfileCardCategory.art);
    });

    test('rarest achievement answers "what I achieved"', () {
      // Without its own arm the `_ => null` default would swallow it and a
      // fresh composition would seed it last instead of with the other
      // accomplishment cards.
      expect(
        cardCategory(ProfileWidgetKind.rarestAchievement),
        ProfileCardCategory.whatIAchieved,
      );
    });

    test('the kind outside the model resolves to no category', () {
      for (final kind in const [ProfileWidgetKind.platform]) {
        expect(cardCategory(kind), isNull, reason: kind.name);
      }
    });

    test('the visual family closes the declared order', () {
      expect(ProfileCardCategory.values.last, ProfileCardCategory.art);
    });
  });

  group('hasDatumZone', () {
    test('art is the only archetype without one', () {
      expect(hasDatumZone(ProfileArchetype.art), isFalse);
      for (final archetype in ProfileArchetype.values) {
        if (archetype == ProfileArchetype.art) continue;
        expect(hasDatumZone(archetype), isTrue, reason: archetype.name);
      }
    });
  });
}
