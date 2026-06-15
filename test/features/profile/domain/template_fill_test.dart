import 'package:featgg/src/features/profile/domain/template_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TemplateFill', () {
    test('empty has a null template id and no slots', () {
      expect(TemplateFill.empty.templateId, isNull);
      expect(TemplateFill.empty.slotItemIds, isEmpty);
      expect(TemplateFill.empty.isEmpty, isTrue);
    });

    test('a fill with a template id is not empty', () {
      expect(const TemplateFill('my_ranks', {}).isEmpty, isFalse);
    });

    test('itemIdFor returns the fill, or null for an unfilled slot', () {
      const fill = TemplateFill('my_ranks', {'slot_1': 'chess.rating'});
      expect(fill.itemIdFor('slot_1'), 'chess.rating');
      expect(fill.itemIdFor('slot_2'), isNull);
    });

    test('withSlot sets a fill without mutating the original', () {
      const fill = TemplateFill('my_ranks', {});
      final next = fill.withSlot('slot_1', 'chess.rating');

      expect(next.itemIdFor('slot_1'), 'chess.rating');
      expect(next.templateId, 'my_ranks');
      // Original is unchanged (immutability).
      expect(fill.slotItemIds, isEmpty);
    });

    test('withSlot replaces an existing fill', () {
      const fill = TemplateFill('my_ranks', {'slot_1': 'chess.rating'});
      final next = fill.withSlot('slot_1', 'gw2.wvw_rank');

      expect(next.itemIdFor('slot_1'), 'gw2.wvw_rank');
      expect(next.slotItemIds, hasLength(1));
    });

    test('clearedSlot removes a fill without mutating the original', () {
      const fill = TemplateFill('my_ranks', {
        'slot_1': 'chess.rating',
        'slot_2': 'gw2.wvw_rank',
      });
      final next = fill.clearedSlot('slot_1');

      expect(next.itemIdFor('slot_1'), isNull);
      expect(next.itemIdFor('slot_2'), 'gw2.wvw_rank');
      // Original is unchanged.
      expect(fill.itemIdFor('slot_1'), 'chess.rating');
    });

    test('value equality holds for equal id + slots', () {
      expect(
        const TemplateFill('my_ranks', {'slot_1': 'chess.rating'}),
        const TemplateFill('my_ranks', {'slot_1': 'chess.rating'}),
      );
      expect(
        const TemplateFill('my_ranks', {'slot_1': 'chess.rating'}),
        isNot(const TemplateFill('my_levels', {'slot_1': 'chess.rating'})),
      );
    });
  });
}
