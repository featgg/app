import 'package:featgg/src/core/theme/personalization_tokens.dart';
import 'package:featgg/src/features/profile/domain/profile_composition.dart';
import 'package:featgg/src/features/profile/presentation/composition_drop_zones.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A rows region 360 wide holding, top to bottom: a gap, a row the dragged card
/// may pair with (an orphan, so its card occupies only the middle third of the
/// column), a gap, a row that offers nothing — so it contributes no zone — and a
/// last gap.
const _bounds = Rect.fromLTWH(0, 0, 360, 500);

const _gap0 = GapZone(index: 0, rect: Rect.fromLTRB(0, 0, 360, 20));
const _pair = PairZone(
  targetId: 'r',
  cardCenterX: 180,
  rect: Rect.fromLTRB(0, 20, 360, 200),
);
const _gap1 = GapZone(index: 1, rect: Rect.fromLTRB(0, 200, 360, 220));
// The row spanning 220..400 offers nothing and so has no zone at all.
const _gap2 = GapZone(index: 2, rect: Rect.fromLTRB(0, 400, 360, 420));

/// Gaps first, in index order, exactly as the editor appends them.
const _zones = <DropZone>[_gap0, _gap1, _gap2, _pair];

/// Below the region but inside the forgiving margin, and past the end of it.
const double _withinTheMargin = PersonalizationLayout.dropAcquireRadius / 2;
const double _pastTheRadius = PersonalizationLayout.dropAcquireRadius + 10;

void main() {
  test('a point inside a zone acquires it', () {
    expect(
      resolveDropZone(
        point: const Offset(180, 100),
        bounds: _bounds,
        zones: _zones,
      ),
      _pair,
    );
    expect(
      resolveDropZone(
        point: const Offset(180, 210),
        bounds: _bounds,
        zones: _zones,
      ),
      _gap1,
    );
  });

  test('a point over a row that offers no zone falls to the nearest gap', () {
    // High in the dead row: the gap above is the nearer of the two.
    expect(
      resolveDropZone(
        point: const Offset(180, 250),
        bounds: _bounds,
        zones: _zones,
      ),
      _gap1,
    );
    // Low in the same row: the gap below.
    expect(
      resolveDropZone(
        point: const Offset(180, 380),
        bounds: _bounds,
        zones: _zones,
      ),
      _gap2,
    );
  });

  test(
    'a point beside an orphan card, outside it, still acquires the pair',
    () {
      // The orphan's card spans 93..267; this point is in the empty left band.
      expect(
        resolveDropZone(
          point: const Offset(40, 110),
          bounds: _bounds,
          zones: _zones,
        ),
        _pair,
      );
    },
  );

  test('sideFor answers left of the card\'s centre and right of it', () {
    expect(_pair.sideFor(const Offset(40, 110)), DropSide.left);
    expect(_pair.sideFor(const Offset(170, 110)), DropSide.left);
    expect(_pair.sideFor(const Offset(320, 110)), DropSide.right);
  });

  test('a point past the radius outside the bounds holds nothing', () {
    expect(
      resolveDropZone(
        point: Offset(180, _bounds.bottom + _pastTheRadius),
        bounds: _bounds,
        zones: _zones,
      ),
      isNull,
    );
  });

  test('a point just outside the bounds still acquires the nearest zone', () {
    expect(
      resolveDropZone(
        point: Offset(180, _bounds.bottom + _withinTheMargin),
        bounds: _bounds,
        zones: _zones,
      ),
      _gap2,
    );
  });

  test('the held zone survives a rival that is nearer by less than the '
      'hysteresis, and yields to one that is nearer by more', () {
    // 10px past the boundary the pair shares with the gap below it.
    expect(
      resolveDropZone(
        point: const Offset(180, 210),
        bounds: _bounds,
        zones: _zones,
        current: _pair,
        hysteresis: 12,
      ),
      _pair,
    );
    // 16px past it, and the gap takes over.
    expect(
      resolveDropZone(
        point: const Offset(180, 216),
        bounds: _bounds,
        zones: _zones,
        current: _pair,
        hysteresis: 12,
      ),
      _gap1,
    );
  });

  test('leaving the bounds drops the held zone even with hysteresis', () {
    expect(
      resolveDropZone(
        point: Offset(180, _bounds.bottom + _pastTheRadius),
        bounds: _bounds,
        zones: _zones,
        current: _pair,
        hysteresis: 1000,
      ),
      isNull,
    );
  });

  test('no zones holds nothing', () {
    expect(
      resolveDropZone(
        point: const Offset(180, 100),
        bounds: _bounds,
        zones: const [],
      ),
      isNull,
    );
  });
}
