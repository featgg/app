import 'package:clock/clock.dart';
import 'package:featgg/src/core/widgets/cooldown_countdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

// testWidgets already runs in a fake-async zone whose clock drives both
// clock.now() and the widget's periodic Timer; deadlines are computed from
// clock.now() (the same source the widget reads) and time is advanced with
// tester.pump(Duration). Each test drains the widget's timer before it ends.
void main() {
  group('CooldownCountdown', () {
    testWidgets('renders the initial remaining seconds via label', (
      tester,
    ) async {
      final captured = <int>[];
      final until = clock.now().add(const Duration(seconds: 10));

      await tester.pumpWidget(
        _wrap(
          CooldownCountdown(
            until: until,
            label: (s) {
              captured.add(s);
              return 'remaining:$s';
            },
          ),
        ),
      );

      expect(captured, isNotEmpty);
      expect(captured.last, greaterThan(0));
      expect(captured.last, lessThanOrEqualTo(10));

      // Dispose to cancel the pending timer.
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    });

    testWidgets('renders nothing when the deadline is already past', (
      tester,
    ) async {
      final past = clock.now().subtract(const Duration(seconds: 5));

      await tester.pumpWidget(
        _wrap(CooldownCountdown(until: past, label: (s) => 'remaining:$s')),
      );

      expect(find.text('remaining:0'), findsNothing);
      expect(find.byType(CooldownCountdown), findsOneWidget);
      // remaining <= 0 schedules no timer, so nothing to drain.
    });

    testWidgets('decrements each second', (tester) async {
      final captured = <int>[];
      final until = clock.now().add(const Duration(seconds: 5));

      await tester.pumpWidget(
        _wrap(
          CooldownCountdown(
            until: until,
            label: (s) {
              captured.add(s);
              return 'remaining:$s';
            },
          ),
        ),
      );
      final initial = captured.last;
      expect(initial, greaterThan(0));

      await tester.pump(const Duration(seconds: 1));
      expect(captured.last, lessThan(initial));

      // Advance past the deadline — the widget cancels its own timer at zero.
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('cancels its timer on dispose (no pending timer)', (
      tester,
    ) async {
      final until = clock.now().add(const Duration(seconds: 30));

      await tester.pumpWidget(
        _wrap(CooldownCountdown(until: until, label: (s) => 'remaining:$s')),
      );

      // Dispose by replacing the tree. An uncancelled timer would fail the test
      // with a pending-timer assertion.
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    });

    testWidgets('reschedules when until changes', (tester) async {
      final captured = <int>[];

      await tester.pumpWidget(
        _wrap(
          CooldownCountdown(
            until: clock.now().add(const Duration(seconds: 5)),
            label: (s) {
              captured.add(s);
              return 'remaining:$s';
            },
          ),
        ),
      );
      final afterFirst = captured.last;

      await tester.pumpWidget(
        _wrap(
          CooldownCountdown(
            until: clock.now().add(const Duration(seconds: 20)),
            label: (s) {
              captured.add(s);
              return 'remaining:$s';
            },
          ),
        ),
      );

      // The further-out deadline yields a larger remaining-seconds value.
      expect(captured.last, greaterThan(afterFirst));

      // Drain the rescheduled timer.
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    });
  });
}
