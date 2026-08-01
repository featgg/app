import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Security gate: the app must never request the account's pending-deletion
/// marker column from the data API. That column is visible to every client that
/// can see the row, so reading it here is what keeps the service from narrowing
/// the grant. The signed-in user's pending-deletion state comes from the
/// owner-scoped status operation instead, so the column name has no reason to
/// appear anywhere in `lib/` — not in a column list, not in a DTO key, not in
/// generated output.
///
/// Unlike the sibling isolation gate, comment lines are NOT skipped: a comment
/// naming the column is the seed of the next column list that requests it.
void main() {
  test('no source under lib/ requests the pending-deletion column', () {
    final dir = Directory('lib');
    expect(dir.existsSync(), isTrue, reason: 'lib/ must exist');

    const column = 'deletion_requested_at';
    var scanned = 0;
    final offenders = <String>[];

    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      scanned++;
      if (entity.readAsStringSync().contains(column)) {
        offenders.add('${entity.path}: names $column');
      }
    }

    // Without this the gate would pass vacuously if the walk ever found
    // nothing (wrong cwd, moved directory).
    expect(scanned, greaterThan(0), reason: 'no .dart file was scanned');
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
