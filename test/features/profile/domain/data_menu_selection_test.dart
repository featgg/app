import 'package:featgg/src/features/profile/domain/data_menu_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DataMenuSelection', () {
    test('empty is the default', () {
      expect(DataMenuSelection.empty.isDefault, isTrue);
      expect(DataMenuSelection.empty.selectedIds, isEmpty);
    });

    test('toggle adds an absent id', () {
      final next = DataMenuSelection.empty.toggle('steam.hours_played');
      expect(next.selectedIds, {'steam.hours_played'});
      expect(next.isDefault, isFalse);
      expect(next.contains('steam.hours_played'), isTrue);
    });

    test('toggle removes a present id', () {
      final once = DataMenuSelection.empty.toggle('a');
      final twice = once.toggle('a');
      expect(twice.selectedIds, isEmpty);
      expect(twice.isDefault, isTrue);
    });

    test('toggle leaves the original untouched (immutability)', () {
      const base = DataMenuSelection.empty;
      base.toggle('a');
      expect(base.selectedIds, isEmpty);
    });

    test('value equality holds for equal id sets', () {
      expect(
        const DataMenuSelection({'a', 'b'}),
        const DataMenuSelection({'b', 'a'}),
      );
      expect(
        const DataMenuSelection({'a'}) == const DataMenuSelection({'a', 'b'}),
        isFalse,
      );
    });
  });
}
