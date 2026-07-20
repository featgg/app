import 'package:featgg/src/features/profile/domain/profile_composition.dart';
import 'package:featgg/src/features/profile/domain/profile_layout.dart';
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

  group('moveToGap (drag out of a pair into a gap → own row)', () {
    test(
      'a half-capable card dragged to a gap becomes its own full row and the '
      'ex-partner stays a centered orphan',
      () {
        // AC1: pull 'ms' out of the pair; 'main' is untouched below.
        const rows = [PairRow(left: 'ms', right: 'rankA'), FullRow('main')];
        // Drop into the gap after the last row (index 2).
        final result = moveToGap(rows, 'ms', 2, supportsFull: _supportsFull);

        expect(result, const [
          PairRow(right: 'rankA'), // ex-partner orphaned in place
          FullRow('main'), // untouched row did not move
          FullRow('ms'), // dragged card is now its own full row
        ]);
      },
    );

    test('decrements the target index when the removed full row sat before the '
        'gap', () {
      const rows = [FullRow('x'), FullRow('y')];
      // Ask to insert at gap index 2 (end). Removing 'x' (row 0) shifts it to 1.
      final result = moveToGap(rows, 'x', 2, supportsFull: _supportsFull);
      expect(result, const [FullRow('y'), FullRow('x')]);
    });

    test('a full-only card dropped in a gap lands as a single-slot pair', () {
      const rows = [FullRow('main'), FullRow('id')];
      // Move the full-only 'id' up into the first gap.
      final result = moveToGap(rows, 'id', 0, supportsFull: _supportsFull);
      expect(result.first, const FullRow('id'));

      // A card that supports neither... here 'rankA' is half-only → orphan pair.
      const halfRows = [
        FullRow('main'),
        PairRow(left: 'rankA', right: 'rankB'),
      ];
      final orphaned = moveToGap(
        halfRows,
        'rankA',
        0,
        supportsFull: _supportsFull,
      );
      expect(orphaned.first, const PairRow(left: 'rankA'));
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

  group('pairableRowIndices (glow set)', () {
    test('a half-capable card glows every row with a half-capable partner and '
        'room', () {
      // AC4: dragging 'rankB' (half). Row 0 full 'main' (half-capable) → glows;
      // row 1 full 'id' (full-only) → no glow; row 2 already-full pair → no glow.
      const rows = [
        FullRow('main'),
        FullRow('id'),
        PairRow(left: 'rankA', right: 'ms'),
      ];
      final glow = pairableRowIndices(
        rows,
        'rankB',
        supportsHalf: _supportsHalf,
      );
      expect(glow, {0});
    });

    test('a full-only dragged card glows nothing', () {
      const rows = [FullRow('main'), PairRow(left: 'ms')];
      final glow = pairableRowIndices(rows, 'id', supportsHalf: _supportsHalf);
      expect(glow, isEmpty);
    });

    test('an orphan row glows for a half-capable card', () {
      const rows = [PairRow(left: 'ms')];
      final glow = pairableRowIndices(
        rows,
        'rankA',
        supportsHalf: _supportsHalf,
      );
      expect(glow, {0});
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
      // 'rankB' is half-only, so its own row is a centered orphan, not full.
      final afterMove = moveToGap(
        start,
        'rankB',
        3,
        supportsFull: _supportsFull,
      );
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

  test('mutations return new lists and never mutate the input', () {
    const rows = [FullRow('ms'), FullRow('main')];
    final before = [...rows];
    moveToGap(rows, 'ms', 2, supportsFull: _supportsFull);
    toggleSize(rows, 'ms');
    pairBeside(rows, 'ms', 'main', DropSide.left);
    normalizeLayout(rows, {'main'});
    expect(rows, before);
  });
}
