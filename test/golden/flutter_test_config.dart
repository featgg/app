import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

/// Scoped to `test/golden/**` on purpose: the runner takes the nearest config
/// walking up from each test file, so swapping the font here cannot change a
/// text metric in any other suite.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadGoldenFonts();
  await testMain();
}
