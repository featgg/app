import 'package:featgg/src/features/profile/domain/profile_composition.dart';
import 'package:featgg/src/features/profile/domain/profile_layout.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:flutter_test/flutter_test.dart';

// Card ids used across the transitions, with a fixed size registry:
//  - full+half capable: 'ms', 'main', 'note', 'x', 'y'
//  - half only: 'rankA', 'rankB'
//  - full only: 'id' (an identity-style card)
const _halfCapable = {'ms', 'main', 'note', 'x', 'y', 'rankA', 'rankB'};
const _fullCapable = {'ms', 'main', 'note', 'x', 'y', 'id'};

bool _supportsHalf(String id) => _halfCapable.contains(id);
bool _supportsFull(String id) => _fullCapable.contains(id);

void main() {
  group('isOrphanRow', () {
    test('a pair with one filled slot is an orphan; a full pair is not', () {
      expect(isOrphanRow(const PairRow(left: 'a')), isTrue);
      expect(isOrphanRow(const PairRow(right: 'a')), isTrue);
      expect(isOrphanRow(const PairRow(left: 'a', right: 'b')), isFalse);
      expect(isOrphanRow(const FullRow('a')), isFalse);
    });
  });

  group('normalizeLayout', () {
    test('drops a full row whose card id is unknown', () {
      final result = normalizeLayout(
        const [FullRow('gone'), FullRow('keep')],
        {'keep'},
      );
      expect(result, const [FullRow('keep')]);
    });

    test('nulls an unknown pair slot and centers the surviving card', () {
      final result = normalizeLayout(
        const [PairRow(left: 'gone', right: 'keep')],
        {'keep'},
      );
      expect(result, const [PairRow(right: 'keep')]);
    });

    test('collapses a pair whose both ids are unknown', () {
      final result = normalizeLayout(
        const [PairRow(left: 'gone', right: 'also-gone'), FullRow('keep')],
        {'keep'},
      );
      expect(result, const [FullRow('keep')]);
    });

    test('keeps a disabled-but-present id (known ids include disabled)', () {
      // A disabled card is still a known widget id, so its slot is preserved.
      final result = normalizeLayout(const [FullRow('disabled')], {'disabled'});
      expect(result, const [FullRow('disabled')]);
    });

    test('preserves order', () {
      final result = normalizeLayout(
        const [FullRow('a'), FullRow('b'), FullRow('c')],
        {'a', 'b', 'c'},
      );
      expect(result, const [FullRow('a'), FullRow('b'), FullRow('c')]);
    });
  });

  group('moveToGap (a move keeps the size, it does not resize)', () {
    test(
      'a half card dropped into a gap keeps its size and lands as a centered '
      'orphan',
      () {
        // Pull 'ms' out of the pair; 'main' is untouched below. 'ms' supports
        // full, so a rule reading the registry would promote it — the size
        // comes from the row it sat in, which was a pair slot.
        const rows = [PairRow(left: 'ms', right: 'rankA'), FullRow('main')];
        // Drop into the gap after the last row (index 2).
        final result = moveToGap(rows, 'ms', 2);

        expect(result, const [
          PairRow(right: 'rankA'), // ex-partner orphaned in place
          FullRow('main'), // untouched row did not move
          PairRow(left: 'ms'), // dragged card still half, now centered
        ]);
      },
    );

    test('a full card dropped into a gap stays full, and the target index '
        'decrements when the removed row sat before the gap', () {
      const rows = [FullRow('main'), FullRow('x')];
      // Ask to insert at gap index 2 (end). Removing 'main' (row 0) shifts it
      // to 1.
      final result = moveToGap(rows, 'main', 2);
      expect(result, const [FullRow('x'), FullRow('main')]);
    });

    test('the row the card sat in decides the size, not the registry', () {
      // 'id' is full-only and sits in a full row → stays full.
      const rows = [FullRow('main'), FullRow('id')];
      expect(moveToGap(rows, 'id', 0).first, const FullRow('id'));

      // 'rankA' is half-only and sits in a pair slot → centered orphan.
      const halfRows = [
        FullRow('main'),
        PairRow(left: 'rankA', right: 'rankB'),
      ];
      expect(
        moveToGap(halfRows, 'rankA', 0).first,
        const PairRow(left: 'rankA'),
      );
    });

    test('a layout that no longer holds the card is returned untouched', () {
      // The delete affordance stays live while a card is in the air, so the
      // release can arrive after the card is gone; re-inserting it would
      // resurrect a row for a widget that no longer exists.
      const rows = [FullRow('main'), PairRow(left: 'ms', right: 'rankA')];
      expect(moveToGap(rows, 'gone', 1), rows);
    });
  });

  group('pairBeside', () {
    test('pairs a card beside an orphan\'s empty half in one move', () {
      // AC2: 'rankB' joins the orphan holding 'ms'.
      const rows = [PairRow(left: 'ms'), FullRow('rankB')];
      final result = pairBeside(rows, 'rankB', 'ms', DropSide.right);
      expect(result, const [PairRow(left: 'ms', right: 'rankB')]);
    });

    test('dropping on a partner\'s opposite side swaps left/right', () {
      // AC3: swap within the same pair.
      const rows = [PairRow(left: 'rankA', right: 'rankB')];
      final result = pairBeside(rows, 'rankA', 'rankB', DropSide.right);
      expect(result, const [PairRow(left: 'rankB', right: 'rankA')]);
    });

    test('moving a card from another row leaves an orphan behind', () {
      const rows = [PairRow(left: 'ms', right: 'main'), FullRow('note')];
      // Pull 'main' out to pair beside 'note'.
      final result = pairBeside(rows, 'main', 'note', DropSide.left);
      expect(result, const [
        PairRow(left: 'ms'), // 'main' removed, 'ms' orphaned
        PairRow(left: 'main', right: 'note'),
      ]);
    });
  });

  group('toggleSize', () {
    test('full → in-place single-slot pair (orphan half)', () {
      const rows = [FullRow('ms')];
      expect(toggleSize(rows, 'ms'), const [PairRow(left: 'ms')]);
    });

    test('half with a partner → partner centered in place, card to a new full '
        'row right after', () {
      const rows = [PairRow(left: 'ms', right: 'main'), FullRow('note')];
      final result = toggleSize(rows, 'ms');
      expect(result, const [
        PairRow(left: 'main'), // ex-partner centered in place
        FullRow('ms'), // card promoted to full right after
        FullRow('note'), // untouched
      ]);
    });

    test('half with no partner (orphan) → full in place', () {
      const rows = [PairRow(left: 'ms')];
      expect(toggleSize(rows, 'ms'), const [FullRow('ms')]);
    });

    test('an id that is not placed is a no-op', () {
      const rows = [FullRow('ms')];
      expect(toggleSize(rows, 'absent'), const [FullRow('ms')]);
    });
  });

  group('canPairBeside (side-drop guard)', () {
    test('accepts beside a full half-capable card', () {
      const rows = [FullRow('main')];
      expect(
        canPairBeside(rows, 0, 'rankA', 'main', supportsHalf: _supportsHalf),
        isTrue,
      );
    });

    test('rejects when the target is full-only', () {
      const rows = [FullRow('id')];
      expect(
        canPairBeside(rows, 0, 'rankA', 'id', supportsHalf: _supportsHalf),
        isFalse,
      );
    });

    test('rejects when the dragged card is full-only', () {
      const rows = [FullRow('main')];
      expect(
        canPairBeside(rows, 0, 'id', 'main', supportsHalf: _supportsHalf),
        isFalse,
      );
    });

    test('rejects a third card onto an already-full pair', () {
      const rows = [PairRow(left: 'rankA', right: 'rankB')];
      expect(
        canPairBeside(rows, 0, 'ms', 'rankA', supportsHalf: _supportsHalf),
        isFalse,
      );
    });

    test(
      'accepts the same-row partner (the swap), rejects dropping on self',
      () {
        const rows = [PairRow(left: 'rankA', right: 'rankB')];
        expect(
          canPairBeside(rows, 0, 'rankA', 'rankB', supportsHalf: _supportsHalf),
          isTrue,
        );
        expect(
          canPairBeside(rows, 0, 'rankA', 'rankA', supportsHalf: _supportsHalf),
          isFalse,
        );
      },
    );
  });

  group('pairTargetAt (the one card a row offers)', () {
    test('offers the other half-capable card of a full row', () {
      const rows = [FullRow('main')];
      expect(
        pairTargetAt(rows, 0, 'rankA', supportsHalf: _supportsHalf),
        'main',
      );
    });

    test('offers an orphan\'s card', () {
      const rows = [PairRow(left: 'ms')];
      expect(pairTargetAt(rows, 0, 'rankA', supportsHalf: _supportsHalf), 'ms');
    });

    test('offers the dragged card\'s own pair partner (the swap)', () {
      const rows = [PairRow(left: 'rankA', right: 'rankB')];
      expect(
        pairTargetAt(rows, 0, 'rankA', supportsHalf: _supportsHalf),
        'rankB',
      );
    });

    test('offers nothing beside a full-only target', () {
      const rows = [FullRow('id')];
      expect(pairTargetAt(rows, 0, 'rankA', supportsHalf: _supportsHalf), null);
    });

    test('offers nothing to a full-only dragged card', () {
      const rows = [FullRow('main')];
      expect(pairTargetAt(rows, 0, 'id', supportsHalf: _supportsHalf), null);
    });

    test('offers nothing on a pair already holding two other cards', () {
      const rows = [PairRow(left: 'rankA', right: 'rankB')];
      expect(pairTargetAt(rows, 0, 'ms', supportsHalf: _supportsHalf), null);
    });

    test('offers nothing on the row holding only the dragged card', () {
      const rows = [PairRow(left: 'rankA')];
      expect(pairTargetAt(rows, 0, 'rankA', supportsHalf: _supportsHalf), null);
    });

    test('offers a target exactly on the rows that have room for one', () {
      // The one indicator promises what a drop delivers, so which rows offer a
      // target is the whole of what the editor may mark.
      const rows = [
        FullRow('main'), // half-capable, has room
        FullRow('id'), // full-only target
        PairRow(left: 'rankA', right: 'ms'), // no room for a third
        PairRow(left: 'note'), // orphan with an empty half
      ];

      final offering = {
        for (var i = 0; i < rows.length; i++)
          if (pairTargetAt(rows, i, 'rankB', supportsHalf: _supportsHalf) !=
              null)
            i,
      };
      expect(offering, {0, 3});
    });
  });

  group('composed mutation locality (AC5)', () {
    test('an orphan→move→toggle→pair sequence never disturbs an untouched row '
        'or blanks a slot', () {
      // Start: an untouched full row, a full pair, and an orphan.
      const start = [
        FullRow('note'), // untouched throughout
        PairRow(left: 'rankA', right: 'rankB'),
        PairRow(left: 'ms'),
      ];

      // 1) Pull 'rankB' out into the last gap → its own row; 'rankA' orphaned.
      // It lands as a centered orphan because it was half where it sat, which
      // a move preserves.
      final afterMove = moveToGap(start, 'rankB', 3);
      expect(afterMove, const [
        FullRow('note'),
        PairRow(left: 'rankA'),
        PairRow(left: 'ms'),
        PairRow(left: 'rankB'),
      ]);

      // 2) Toggle 'ms' (orphan half) to full in place.
      final afterToggle = toggleSize(afterMove, 'ms');
      expect(afterToggle, const [
        FullRow('note'),
        PairRow(left: 'rankA'),
        FullRow('ms'),
        PairRow(left: 'rankB'),
      ]);

      // 3) Pair 'rankB' beside the 'rankA' orphan.
      final afterPair = pairBeside(
        afterToggle,
        'rankB',
        'rankA',
        DropSide.right,
      );
      expect(afterPair, const [
        FullRow('note'), // still first, still untouched
        PairRow(left: 'rankA', right: 'rankB'),
        FullRow('ms'),
      ]);

      // The untouched row is byte-for-byte where it started.
      expect(afterPair.first, start.first);
    });
  });

  group('removeCard', () {
    test('removes a full row', () {
      const rows = [FullRow('a'), FullRow('b')];
      expect(removeCard(rows, 'a'), const [FullRow('b')]);
    });

    test('nulls a pair slot and centers the surviving card', () {
      const rows = [PairRow(left: 'a', right: 'b')];
      expect(removeCard(rows, 'a'), const [PairRow(right: 'b')]);
    });

    test('drops a pair that the removal empties', () {
      const rows = [PairRow(left: 'a'), FullRow('b')];
      expect(removeCard(rows, 'a'), const [FullRow('b')]);
    });

    test('preserves order', () {
      const rows = [FullRow('a'), FullRow('b'), FullRow('c')];
      expect(removeCard(rows, 'b'), const [FullRow('a'), FullRow('c')]);
    });

    test('is a no-op on an absent id', () {
      const rows = [FullRow('a'), PairRow(left: 'b', right: 'c')];
      expect(removeCard(rows, 'zzz'), rows);
    });

    test('does not mutate the input list', () {
      const rows = [FullRow('a'), FullRow('b')];
      final before = [...rows];
      removeCard(rows, 'a');
      expect(rows, before);
    });
  });

  test('mutations return new lists and never mutate the input', () {
    const rows = [FullRow('ms'), FullRow('main')];
    final before = [...rows];
    moveToGap(rows, 'ms', 2);
    toggleSize(rows, 'ms');
    pairBeside(rows, 'ms', 'main', DropSide.left);
    normalizeLayout(rows, {'main'});
    expect(rows, before);
  });

  group('defaultLayoutFor', () {
    ProfileWidget widget(
      String id,
      ProfileWidgetKind kind, {
      int position = 0,
      bool enabled = true,
    }) => ProfileWidget(
      id: id,
      kind: kind,
      platform: null,
      position: position,
      isEnabled: enabled,
    );

    test('orders by question-category, position breaking ties', () {
      final rows = defaultLayoutFor([
        widget('art', ProfileWidgetKind.art, position: 0),
        widget('rank', ProfileWidgetKind.rank, position: 1),
        widget('who', ProfileWidgetKind.passport, position: 2),
      ]);

      expect(rows, const [FullRow('who'), FullRow('rank'), FullRow('art')]);
    });

    test('keeps a hidden widget, so the editor can still reach it', () {
      // Dropping it here would strand it: the add catalog counts it as
      // already added, while no surface would offer a way to remove it.
      final rows = defaultLayoutFor([
        widget('shown', ProfileWidgetKind.passport),
        widget('hidden', ProfileWidgetKind.rank, enabled: false),
      ]);

      expect(rows, const [FullRow('shown'), FullRow('hidden')]);
    });

    test('a half-only card seeds as a single-slot pair', () {
      final rows = defaultLayoutFor([
        widget('rankA', ProfileWidgetKind.rank),
      ], supportsFull: _supportsFull);

      expect(rows, const [PairRow(left: 'rankA')]);
    });
  });
}
