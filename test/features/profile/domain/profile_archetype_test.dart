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
          archetypeForWidget(_widget(kind)),
          isNot(ProfileArchetype.fallback),
          reason: '$kind should map to a designed archetype, not fallback',
        );
      }
    });

    test('every other kind falls through to fallback', () {
      for (final kind in const [
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
        ProfileArchetype.fallback,
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

  group('cardCategory (spec §7)', () {
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

    test('the kinds outside the model resolve to no category', () {
      for (final kind in const [
        ProfileWidgetKind.platform,
        ProfileWidgetKind.template,
        ProfileWidgetKind.composed,
        ProfileWidgetKind.dataMenu,
      ]) {
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
